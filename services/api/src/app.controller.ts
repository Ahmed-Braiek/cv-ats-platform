import {
  Controller, Get, Headers, HttpException, HttpStatus, Param,
  ParseUUIDPipe, Query, BadRequestException,
} from '@nestjs/common';
import { SupabaseService } from './supabase.service';

type ApiResult<T> = { data: T };

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
