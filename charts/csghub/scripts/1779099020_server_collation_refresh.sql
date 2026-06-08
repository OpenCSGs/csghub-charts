--
-- Record Timestamp
--
SELECT now() as "Execute Timestamp";

--
-- Refresh Database Collation Version
--
-- Purpose:
--   Synchronize the database collation version with the underlying OS / libc version.
--   Automatically skips if collation version is already up to date.
--   Catches insufficient privilege gracefully so the overall job is not interrupted.
--
-- Background:
--   When upgrading PostgreSQL major versions (e.g. 15 → 16) or when the OS glibc
--   version changes, PostgreSQL may detect a collation version mismatch and emit:
--     "database collation version mismatch"
--

DO $$
DECLARE
    db RECORD;
BEGIN
    FOR db IN
        SELECT datname
        FROM pg_database
        WHERE datallowconn = true
          AND datname NOT IN ('template0', 'template1', 'postgres')
    LOOP
        BEGIN
            EXECUTE format('ALTER DATABASE %I REFRESH COLLATION VERSION', db.datname);
            RAISE NOTICE 'Collation version refreshed for %', db.datname;
        EXCEPTION
            WHEN insufficient_privilege THEN
                RAISE WARNING 'Insufficient privilege to refresh collation version for %, skipping', db.datname;
            WHEN OTHERS THEN
                RAISE WARNING 'Unexpected error refreshing collation version for %: %', db.datname, SQLERRM;
        END;
    END LOOP;
END
$$;