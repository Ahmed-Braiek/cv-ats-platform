import {
  Injectable, ServiceUnavailableException, UnauthorizedException,
} from '@nestjs/common';
import { createClient, SupabaseClient, User } from '@supabase/supabase-js';

@Injectable()
export class SupabaseService {
  private readonly url = process.env.SUPABASE_URL;
  private readonly publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY;

  private config(): { url: string; key: string } {
    if (!this.url || !this.publishableKey) {
      throw new ServiceUnavailableException('Supabase is not configured');
    }
    return { url: this.url, key: this.publishableKey };
  }

  /**
   * Uses the publishable key and a verified user's access token.
   * Queries remain subject to Supabase RLS; no service_role bypass.
   */
  userClient(accessToken: string): SupabaseClient {
    const { url, key } = this.config();
    return createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
  }

  publicClient(): SupabaseClient {
    const { url, key } = this.config();
    return createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }

  async verifyBearer(header?: string): Promise<{ token: string; user: User }> {
    const match = /^Bearer\s+(\S+)$/i.exec(header ?? '');
    if (!match) throw new UnauthorizedException('Bearer token required');
    const token = match[1];
    const { data, error } = await this.publicClient().auth.getUser(token);
    if (error || !data.user) throw new UnauthorizedException('Invalid or expired session');
    return { token, user: data.user };
  }
}
