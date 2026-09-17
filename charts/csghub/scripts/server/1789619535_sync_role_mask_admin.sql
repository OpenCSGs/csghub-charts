--
-- Sync csghub_server.public.users.role_mask to csghub_casdoor.public."user".is_admin
--
-- Sets up postgres_fdw in csghub_server, maps public."user" via a foreign table,
-- and installs an AFTER INSERT/UPDATE OF role_mask trigger on public.users.
--
-- Mapping rule (matches csghub-server User.CanAdmin()):
--   role_mask is varchar(255), comma-separated.
--   contains 'admin' or 'super_user'  -> is_admin = true
--   otherwise                          -> is_admin = false
--
-- The companion casdoor script is expected to create csghub_server_fdw and grant
-- access before the backfill runs.
--

-- Record Timestamp

SELECT now() as "Execute Timestamp";

-- Set Default Schema

SELECT pg_catalog.set_config('search_path', 'public', false);

-- Extension

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Foreign Server

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_foreign_server WHERE srvname = 'csghub_casdoor_fdw') THEN
        CREATE SERVER csghub_casdoor_fdw
            FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (host '127.0.0.1', port '5432', dbname 'csghub_casdoor');
        RAISE NOTICE 'Created foreign server csghub_casdoor_fdw';
    ELSE
        RAISE NOTICE 'Foreign server csghub_casdoor_fdw already exists, skipping';
    END IF;
END
$$;

-- User Mapping
-- FOR csghub: trigger function runs with privileges of public.users owner; the
-- mapping must reference the same role or FDW raises "no user mapping found".

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_user_mappings um
        JOIN pg_foreign_server s ON s.oid = um.srvid
        WHERE s.srvname = 'csghub_casdoor_fdw'
          AND um.umuser::regrole::text = 'csghub'
    ) THEN
        CREATE USER MAPPING FOR csghub
            SERVER csghub_casdoor_fdw
            OPTIONS (user 'csghub_server_fdw');
        RAISE NOTICE 'Created user mapping csghub -> csghub_casdoor_fdw';
    ELSE
        RAISE NOTICE 'User mapping csghub -> csghub_casdoor_fdw already exists, skipping';
    END IF;
END
$$;

-- Foreign Table
-- is_admin column is required; the trigger writes it.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_foreign_table ft ON ft.ftrelid = c.oid
        WHERE n.nspname = 'public' AND c.relname = 'casdoor_users'
    ) THEN
        CREATE FOREIGN TABLE public.casdoor_users (
            id        varchar(100),
            is_admin  boolean
        )
        SERVER csghub_casdoor_fdw
        OPTIONS (schema_name 'public', table_name 'user');
        RAISE NOTICE 'Created foreign table public.casdoor_users';
    ELSE
        RAISE NOTICE 'Foreign table public.casdoor_users already exists, skipping';
    END IF;
END
$$;

-- Trigger Function

CREATE OR REPLACE FUNCTION public.sync_casdoor_user_admin()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    desired_is_admin boolean;
BEGIN
    desired_is_admin := COALESCE(
        NEW.role_mask LIKE '%admin%' OR NEW.role_mask LIKE '%super_user%',
        false
    );

    -- Inner EXCEPTION: a remote-side failure must not roll back the originating
    -- INSERT/UPDATE on public.users. The row keeps its new role_mask and the
    -- next role_mask change (or a manual backfill) will retry the sync.

    BEGIN
        UPDATE public.casdoor_users
        SET is_admin = desired_is_admin
        WHERE id = NEW.uuid;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'sync_casdoor_user_admin: remote update failed for uuid=% role_mask=%: %',
                NEW.uuid, NEW.role_mask, SQLERRM;
    END;

    RETURN NEW;
END;
$$;

-- Trigger

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'sync_casdoor_user_admin'
          AND tgrelid = 'public.users'::regclass
    ) THEN
        CREATE TRIGGER sync_casdoor_user_admin
        AFTER INSERT OR UPDATE OF role_mask
        ON public.users
        FOR EACH ROW
        EXECUTE FUNCTION public.sync_casdoor_user_admin();
        RAISE NOTICE 'Created trigger sync_casdoor_user_admin';
    ELSE
        RAISE NOTICE 'Trigger sync_casdoor_user_admin already exists, skipping';
    END IF;
END
$$;

-- Backfill
-- Tolerate failure here: csghubcasdoor pod may not have created the
-- csghub_server_fdw role yet. Next restart retries once casdoor is up.

DO $$
BEGIN
    UPDATE public.casdoor_users c
    SET is_admin = COALESCE(
        u.role_mask LIKE '%admin%' OR u.role_mask LIKE '%super_user%',
        false
    )
    FROM public.users u
    WHERE c.id = u.uuid
      AND c.is_admin IS DISTINCT FROM COALESCE(
          u.role_mask LIKE '%admin%' OR u.role_mask LIKE '%super_user%',
          false
      );

    RAISE NOTICE 'Backfill completed';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Backfill failed (csghubcasdoor pod likely not ready): %; will retry on next restart', SQLERRM;
END
$$;