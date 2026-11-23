import {
  Controller, Get, Headers, HttpException, HttpStatus, Param,
  ParseUUIDPipe, Query, BadRequestException, Body, Post,
} from '@nestjs/common';
import { IsString, IsUUID, MaxLength, MinLength, IsOptional } from 'class-validator';
import { SupabaseService } from './supabase.service';

type ApiResult<T> = { data: T };

class SubmitAnalysisDto {
  @IsUUID()
  cvId!: string;

  @IsString()
  @MinLength(20)
  @MaxLength(16000)
  jobDescription!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  jobTitle?: string;
}

@Controller()
export class AppController {
  constructor(private readonly supabase: SupabaseService) {}

  @Get('health')
  health(): ApiResult<{ status: string; service: string }> {
    return { data: { status: 'ok', service: 'cv-ats-api' } };
  }

  @Get('plans')
  async plans(): Promise<ApiResult<unknown>> {
    const { data, error } = await this.supabase.publicClient()
      .from('subscription_plans')
      .select('id,code,name,monthly_analysis_limit,saved_cv_limit,history_days,pdf_export_enabled')
      .eq('active', true)
      .order('monthly_analysis_limit');
    if (error) throw new HttpException('Unable to load plans', HttpStatus.BAD_GATEWAY);
    return { data: data ?? [] };
  }

  @Get('me')
  async me(@Headers('authorization') authorization?: string): Promise<ApiResult<unknown>> {
    const { token, user } = await this.supabase.verifyBearer(authorization);
    const { data, error } = await this.supabase.userClient(token)
      .from('profiles')
      .select('id,display_name,created_at')
      .eq('id', user.id)
      .maybeSingle();
    if (error) throw new HttpException('Unable to load profile', HttpStatus.BAD_GATEWAY);
    return { data: { id: user.id, email: user.email, profile: data } };
  }

  @Get('cvs')
  async cvs(
    @Headers('authorization') authorization?: string,
  ): Promise<ApiResult<unknown>> {
    const { token, user } = await this.supabase.verifyBearer(authorization);
    const { data, error } = await this.supabase.userClient(token)
      .from('cvs')
      .select('id,original_name,mime_type,size_bytes,uploaded_at')
      .eq('user_id', user.id)
      .is('deleted_at', null)
      .order('uploaded_at', { ascending: false })
      .limit(50);
    if (error) throw new HttpException('Unable to load CVs', HttpStatus.BAD_GATEWAY);
    return { data: data ?? [] };
  }

  @Post('analyses')
  async submitAnalysis(
    @Headers('authorization') authorization: string,
    @Body() dto: SubmitAnalysisDto,
  ): Promise<ApiResult<unknown>> {
    const { token, user } = await this.supabase.verifyBearer(authorization);
    const client = this.supabase.userClient(token);

    // RLS restricts both records to this candidate. The DB trigger automatically
    // queues the analysis only after its owner/CV/job checks succeed.
    const { data: cv, error: cvError } = await client.from('cvs')
      .select('id').eq('id', dto.cvId).eq('user_id', user.id)
      .is('deleted_at', null).maybeSingle();
    if (cvError || !cv) {
      throw new HttpException('CV not found', HttpStatus.NOT_FOUND);
    }
    const { data: job, error: jobError } = await client
      .from('job_descriptions').insert({
        user_id: user.id,
        title: dto.jobTitle?.trim() || null,
        raw_text: dto.jobDescription.trim(),
      }).select('id').single();
    if (jobError || !job) {
      throw new HttpException('Unable to create job description', HttpStatus.BAD_REQUEST);
    }
    const { data: analysis, error } = await client.from('analyses')
      .insert({
        user_id: user.id,
        cv_id: dto.cvId,
        job_description_id: job.id,
        status: 'queued',
      }).select('id,status,created_at').single();
    if (error || !analysis) {
      throw new HttpException('Analysis could not be queued (quota or input validation)',
        HttpStatus.BAD_REQUEST);
    }
    return { data: analysis };
  }

  @Get('analyses/:id/results')
  async analysisResults(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Headers('authorization') authorization?: string,
  ): Promise<ApiResult<unknown>> {
    const { token, user } = await this.supabase.verifyBearer(authorization);
    const client = this.supabase.userClient(token);
    const { data: analysis, error: analysisError } = await client.from('analyses')
      .select('id,status,created_at,completed_at,failure_code,cv_id')
      .eq('id',id).eq('user_id',user.id).maybeSingle();
    if (analysisError || !analysis) {
      throw new HttpException('Analysis not found',HttpStatus.NOT_FOUND);
    }
    if (analysis.status !== 'completed') {
      return { data: { analysis, ready: false, ats: null, match: null,
        recommendations: [] } };
    }
    const [ats, match, recommendations] = await Promise.all([
      client.from('ats_results').select('overall,rubric_json,evaluator_version')
        .eq('analysis_id',id).maybeSingle(),
      client.from('match_results').select('overall,rubric_json,evaluator_version')
        .eq('analysis_id',id).maybeSingle(),
      client.from('recommendations').select('priority,category,message')
        .eq('analysis_id',id).order('priority'),
    ]);
    if (ats.error || match.error || recommendations.error || !ats.data || !match.data) {
      throw new HttpException('Result unavailable',HttpStatus.BAD_GATEWAY);
    }
    return { data: { analysis, ready: true, ats: ats.data,
      match: match.data, recommendations: recommendations.data ?? [] } };
  }

  @Get('analyses')
  async analyses(
    @Headers('authorization') authorization?: string,
    @Query('limit') rawLimit?: string,
  ): Promise<ApiResult<unknown>> {
    const { token, user } = await this.supabase.verifyBearer(authorization);
    const limit = rawLimit === undefined ? 20 : Number(rawLimit);
    if (!Number.isInteger(limit) || limit < 1 || limit > 50) {
      throw new BadRequestException('limit must be between 1 and 50');
    }
    const { data, error } = await this.supabase.userClient(token)
      .from('analyses')
      .select('id,status,created_at,completed_at,job_description_id,cv_id')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw new HttpException('Unable to load analyses', HttpStatus.BAD_GATEWAY);
    return { data: data ?? [] };
  }

  @Get('analyses/:id')
  async analysis(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Headers('authorization') authorization?: string,
  ): Promise<ApiResult<unknown>> {
    const { token, user } = await this.supabase.verifyBearer(authorization);
    const { data, error } = await this.supabase.userClient(token)
      .from('analyses')
      .select('id,status,created_at,completed_at,job_description_id,cv_id,evaluator_version')
      .eq('id', id).eq('user_id', user.id).maybeSingle();
    if (error) throw new HttpException('Unable to load analysis', HttpStatus.BAD_GATEWAY);
    if (!data) throw new HttpException('Analysis not found', HttpStatus.NOT_FOUND);
    return { data };
  }
}
