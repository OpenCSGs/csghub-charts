--
-- Record Timestamp
--
SELECT now() as "Execute Timestamp";

--
-- Set Default Schema
--
SELECT pg_catalog.set_config('search_path', 'public', false);

--
-- Grant the root user the super_admin role in public.user_roles
--
DO $$
DECLARE
    root_id bigint;
BEGIN
    SELECT id INTO root_id
    FROM public.users
    WHERE username = 'root'
    ORDER BY id
    LIMIT 1;

    IF root_id IS NULL THEN
        RAISE NOTICE 'root user not found in public.users, skipping';
        RETURN;
    END IF;

    INSERT INTO public.user_roles (user_id, role_code, operator_user_id, created_at)
    VALUES (root_id, 'super_admin', root_id, NOW())
    ON CONFLICT (user_id, role_code) WHERE deleted_at IS NULL DO NOTHING;
    RAISE NOTICE 'Ensured super_admin for root user (id=%)', root_id;
EXCEPTION
    WHEN undefined_table THEN
        RAISE WARNING 'public.user_roles or public.users not found, skipping: %', SQLERRM;
END
$$;
