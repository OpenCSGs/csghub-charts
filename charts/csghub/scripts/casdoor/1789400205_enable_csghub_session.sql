--
-- Enable sign-in session for the CSGHub application
--
-- Casdoor's HandleLoggedIn only writes a browser session cookie when
-- application.enable_signin_session is true. The CSGHub portal login
-- uses the CSGHub application, so without this flag Casdoor never
-- establishes a session and the Temporal console's "Sign in with SSO"
-- (which uses the Admin application) prompts for credentials every time.
--
-- init_data.json sets enableSigninSession: true on fresh installs, but
-- casdoor.initDataNewOnly = true means existing application rows are
-- not reseeded on upgrade. This script flips the flag for upgrades.
--

SELECT now() as "Execute Timestamp";

SELECT pg_catalog.set_config('search_path', 'public', false);

DO $$
DECLARE
    current_flag text;
BEGIN
    SELECT enable_signin_session INTO current_flag
    FROM application
    WHERE name = 'CSGHub';

    IF current_flag IS NULL THEN
        RAISE NOTICE 'CSGHub application not found, skipping';
        RETURN;
    END IF;

    IF current_flag = 't' THEN
        RAISE NOTICE 'CSGHub application already has enable_signin_session = true, skipping';
    ELSE
        UPDATE application
        SET enable_signin_session = 't'
        WHERE name = 'CSGHub';

        RAISE NOTICE 'CSGHub application enable_signin_session set to true';
    END IF;
END $$;