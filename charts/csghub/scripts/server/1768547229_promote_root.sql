--
-- Record Timestamp
--
SELECT now() as "Execute Timestamp";

--
-- Set Default Schema
--
SELECT pg_catalog.set_config('search_path', 'public', false);

--
-- Type: Trigger; Schema: public; Owner: csghub
--
-- Create Trigger Function
CREATE OR REPLACE FUNCTION promote_root_to_admin ()
    RETURNS TRIGGER
    AS $$
BEGIN
    IF NEW.username = 'root' THEN
        UPDATE
            public.users
        SET
            role_mask = 'admin'
        WHERE
            username = 'root';

        -- Grant the global administrator role in the RBAC tables. On a fresh
        -- install root only exists after the migration Job has finished, so
        -- this is the only place the assignment can be created there.
        -- Tolerate a missing table so a failure never rolls back the INSERT
        -- that created the root user.
        BEGIN
            INSERT INTO public.user_roles (user_id, role_code, operator_user_id, created_at)
            VALUES (NEW.id, 'super_admin', NEW.id, NOW())
            ON CONFLICT (user_id, role_code) WHERE deleted_at IS NULL DO NOTHING;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'promote_root_to_admin: failed to grant super_admin to root (id=%): %',
                    NEW.id, SQLERRM;
        END;

        -- After update Drop all
        EXECUTE 'DROP TRIGGER IF EXISTS trigger_promote_root_to_admin ON public.users';
        EXECUTE 'DROP FUNCTION IF EXISTS promote_root_to_admin()';
    END IF;
    RETURN NEW;
END;
$$
LANGUAGE plpgsql
VOLATILE;

-- Create Trigger
CREATE OR REPLACE TRIGGER trigger_promote_root_to_admin
    AFTER INSERT ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION promote_root_to_admin ();
