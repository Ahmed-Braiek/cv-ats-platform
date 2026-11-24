-- Global round-robin Gemini key-slot allocator.
-- Stores a counter only; Gemini API key values remain Edge Function secrets.
CREATE TABLE IF NOT EXISTS private.cv_ats_gemini_key_cursor (
  id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  issued bigint NOT NULL DEFAULT 0 CHECK (issued >= 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO private.cv_ats_gemini_key_cursor (id) VALUES (1)
  ON CONFLICT (id) DO NOTHING;
ALTER TABLE private.cv_ats_gemini_key_cursor ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.cv_ats_gemini_key_cursor FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;
GRANT SELECT, UPDATE ON TABLE private.cv_ats_gemini_key_cursor TO service_role;

CREATE OR REPLACE FUNCTION public.cv_ats_next_gemini_slot(p_active_slots integer)
RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  next_issued bigint;
BEGIN
  IF p_active_slots IS NULL OR p_active_slots NOT BETWEEN 1 AND 3 THEN
    RAISE EXCEPTION 'active_slots_must_be_1_to_3';
  END IF;
  -- One atomic UPDATE serializes concurrent Edge Function instances.
  UPDATE private.cv_ats_gemini_key_cursor
    SET issued = issued + 1, updated_at = now()
    WHERE id = 1
    RETURNING issued INTO next_issued;
  IF next_issued IS NULL THEN
    RAISE EXCEPTION 'gemini_cursor_missing';
  END IF;
  RETURN ((next_issued - 1) % p_active_slots + 1)::integer;
END;
$function$;
REVOKE ALL ON FUNCTION public.cv_ats_next_gemini_slot(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cv_ats_next_gemini_slot(integer)
  TO service_role;
COMMENT ON FUNCTION public.cv_ats_next_gemini_slot(integer)
  IS 'Service-only atomic Gemini key-slot allocator (1..3); never stores secrets.';
