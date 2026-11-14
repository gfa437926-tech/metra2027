-- Abort unless every public table in the target is empty.
-- This is a read-only guard; it never changes target data.
DO $$
DECLARE
  item record;
  has_rows boolean;
BEGIN
  FOR item IN
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    ORDER BY schemaname, tablename
  LOOP
    EXECUTE format(
      'SELECT EXISTS (SELECT 1 FROM %I.%I)',
      item.schemaname,
      item.tablename
    ) INTO has_rows;

    IF has_rows THEN
      RAISE EXCEPTION 'Refusing data import: target table %.% is not empty',
        item.schemaname, item.tablename;
    END IF;
  END LOOP;
END
$$;
