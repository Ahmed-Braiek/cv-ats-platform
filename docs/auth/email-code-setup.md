# Supabase email code setup — mandatory for the Flutter signup flow

The Android and web apps now show an email-code verification field after registration. **Supabase must send a code, not only its default confirmation link.** No secret should be pasted into GitHub or ChatGPT.

Project: https://supabase.com/dashboard/project/uqtyxhkevnyjvhwdgkyh

1. Open **Authentication → Providers → Email** (or Sign In / Providers → Email) and confirm **Confirm email** is enabled.
2. Open **Authentication → Email Templates → Confirm signup**:
   https://supabase.com/dashboard/project/uqtyxhkevnyjvhwdgkyh/auth/templates
3. Set subject to **Your CV ATS verification code**.
4. Replace the default HTML body with the file [signup-confirmation-email.html](signup-confirmation-email.html). The critical Supabase token expression is `{{ .Token }}`.
5. Save the email template.
6. Register a **synthetic test email** and verify the message contains a six-digit code. Paste it into the Flutter form.
7. Confirm successful verification creates a logged-in session, candidate profile and Free plan subscription. Test incorrect and expired codes, resend delay, and already-registered accounts.

**Never** use `{{ .ConfirmationURL }}` alone if the design is a pasteable-code-only flow. Supabase OTP/email confirmation handling can still use links in other templates. The client verifies email OTP with `verifyOTP(type: OtpType.email, email: ..., token: ...)`; resend confirmation uses `resend(type: OtpType.signup, email: ...)`.

For real public users, configure a custom transactional SMTP provider, review Supabase Auth sending limits, and verify the sender domain (SPF/DKIM/DMARC).

The default Supabase email provider is not intended to operate as a high-volume production service.

Reference:
- https://supabase.com/docs/guides/auth/auth-email-templates
- https://supabase.com/docs/reference/dart/auth-verifyotp
