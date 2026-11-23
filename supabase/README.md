# Supabase workspace

This directory will contain versioned schema migrations and row-level security tests after the **dedicated project and owning organization are confirmed**.

Do not manually duplicate `auth.users` or store passwords in application tables. `profiles.id` will reference `auth.users.id`.

All CV originals belong in a private storage bucket, and user-visible Postgres tables must have RLS with ownership predicates. Private job and model-call tables must be in an unexposed schema.

No migration has been applied yet. See `docs/architecture/database-plan.md`.
