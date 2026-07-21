--
-- Append Superset redirect URI to Admin application
-- The old migration (1768547229) only sets /-/temporal/auth/sso/callback,
-- Superset needs /-/superset/oauth-authorized/casdoor to be present too.
--

SELECT now() as "Execute Timestamp";

SELECT pg_catalog.set_config('search_path', 'public', false);

SET session.external_endpoint = :'external_endpoint';

DO $$
DECLARE
    external_endpoint text := current_setting('session.external_endpoint', true);
    superset_uri text;
    current_uris text;
BEGIN
    IF external_endpoint IS NULL OR external_endpoint = '' THEN
        RAISE EXCEPTION 'Error: external_endpoint variable not provided';
    END IF;

    superset_uri := rtrim(replace(external_endpoint, '''', ''), '/') || '/-/superset/oauth-authorized/casdoor';

    SELECT redirect_uris INTO current_uris FROM application WHERE name = 'Admin';

    IF current_uris IS NULL THEN
        RAISE NOTICE 'Admin application not found, skipping';
        RETURN;
    END IF;

    IF current_uris LIKE '%' || superset_uri || '%' THEN
        RAISE NOTICE 'Superset redirect URI already exists for Admin, skipping';
    ELSE
        UPDATE application
        SET redirect_uris = (redirect_uris::jsonb || jsonb_build_array(superset_uri))::text
        WHERE name = 'Admin';

        RAISE NOTICE 'Superset redirect URI appended to Admin application';
    END IF;
END $$;
