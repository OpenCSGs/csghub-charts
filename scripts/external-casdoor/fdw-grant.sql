--
-- Grants for the optional CSGHub administrator -> Casdoor is_admin sync.
--
-- Run this on the EXTERNAL Casdoor database (not the CSGHub database) when you
-- want to enable the optional administrator sync in the external Casdoor guide.
-- The CSGHub server connects
-- over postgres_fdw as csghub_server_fdw and updates public."user".is_admin when
-- public.users.role_mask changes.
--
-- Table-level grants are intentional:
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
-- current_database() is the external Casdoor database you are connected to, so
-- this works regardless of its name.

DO $$
BEGIN
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO csghub_server_fdw', current_database());
END
$$;
GRANT USAGE   ON SCHEMA   public       TO csghub_server_fdw;
GRANT SELECT, UPDATE ON public."user" TO csghub_server_fdw;
