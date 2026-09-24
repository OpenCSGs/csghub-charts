--
-- Create FDW user for csghub_server -> csghub_casdoor sync
--
-- Postgres_fdw in csghub_server connects to csghub_casdoor as a dedicated role to
-- update public."user".is_admin when csghub_server.public.users.role_mask changes.
--
-- Grants are table-level:
--   column-level SELECT(id) breaks SELECT * on the foreign table (is_admin denied).
--   column-level UPDATE breaks SELECT ctid FROM "user" FOR UPDATE used internally
--   by postgres_fdw.
--

-- Record Timestamp

SELECT now() as "Execute Timestamp";

-- Set Default Schema

SELECT pg_catalog.set_config('search_path', 'public', false);

-- Create User

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'csghub_server_fdw') THEN
        CREATE USER csghub_server_fdw;
        RAISE NOTICE 'Created user csghub_server_fdw';
    ELSE
        RAISE NOTICE 'User csghub_server_fdw already exists, skipping';
    END IF;
END
$$;

-- Grants
--
-- The database name is not fixed: it derives from casdoor.name / casdoor.postgresql.database.
-- This job connects to that database, so use current_database() instead of a literal.

DO $$
BEGIN
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO csghub_server_fdw', current_database());
END
$$;
GRANT USAGE   ON SCHEMA   public       TO csghub_server_fdw;
GRANT SELECT, UPDATE ON public."user" TO csghub_server_fdw;