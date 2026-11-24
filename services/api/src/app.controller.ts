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
    // Single RLS-protected database transaction: if a quota check rejects
    // the analysis, the new job description is rolled back automatically.
    const { data: rows, error } = await client.rpc('cv_ats_submit_analysis', {
      p_cv_id: dto.cvId,
      p_job_description: dto.jobDescription.trim(),
      p_job_title: dto.jobTitle?.trim() || null,
    });

    if (error) {
      const reason = error.message.toLowerCase();
      if (reason.includes('monthly analysis quota exceeded')) {
        throw new HttpException({
          code: 'MONTHLY_ANALYSIS_LIMIT',
          message: 'Monthly analysis limit reached for your plan. Your quota resets next month, or you can request an upgrade.',
        }, HttpStatus.TOO_MANY_REQUESTS);
      }
      if (reason.includes('too many outstanding analyses')) {
        throw new HttpException({
          code: 'ANALYSIS_QUEUE_FULL',
          message: 'Two analyses are already processing. Please wait for one to finish.',
        }, HttpStatus.CONFLICT);
      }
      if (reason.includes('no active subscription')) {
        throw new HttpException({
          code: 'SUBSCRIPTION_INACTIVE',
          message: 'No active analysis plan found. Check your subscription.',
        }, HttpStatus.FORBIDDEN);
      }
      if (reason.includes('cv_not_found')) {
        throw new HttpException('CV not found', HttpStatus.NOT_FOUND);
      }
      if (reason.includes('job_description_length_invalid') ||
          reason.includes('job_title_length_invalid')) {
        throw new HttpException('Invalid job details', HttpStatus.BAD_REQUEST);
      }
      // Do not leak database errors, CV content or internal policy details.
      throw new HttpException('Unable to create analysis. Please try again later.',
        HttpStatus.BAD_GATEWAY);
    }

    const analysis = Array.isArray(rows) ? rows[0] : null;
    if (!analysis?.id) {
      throw new HttpException('Analysis was not created', HttpStatus.BAD_GATEWAY);
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
