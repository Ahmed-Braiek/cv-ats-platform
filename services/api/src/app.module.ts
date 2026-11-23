import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { SupabaseService } from './supabase.service';

@Module({
  controllers: [AppController],
  providers: [SupabaseService],
})
export class AppModule {}
