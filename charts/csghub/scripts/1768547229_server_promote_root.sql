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
