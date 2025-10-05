-- casdoor_database_update.sql
-- PostgreSQL database update script for Casdoor
-- Usage: psql -v external_endpoint="your_endpoint" [...] -f casdoor_database_update.sql

--
-- Record execution timestamp
--
SELECT now() as "Execute Timestamp";

--
-- PostgreSQL database configuration
--
SET exit_on_error = on;
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Import psql variables into session settings
--
SET session.external_endpoint = :'external_endpoint';
SET session.oauth_client_id = :'oauth_client_id';
SET session.oauth_client_secret = :'oauth_client_secret';
SET session.oauth_issuer = :'oauth_issuer';

--
-- Set Default Schema for All Tables
--
SELECT pg_catalog.set_config('search_path', 'public', false);

--
DO $$
DECLARE
    external_endpoint text := current_setting('session.external_endpoint', true);
BEGIN
    IF external_endpoint IS NULL OR external_endpoint = '' THEN
        RAISE EXCEPTION 'Error: external_endpoint variable not provided';
    END IF;
END $$;

--
-- Update RedirectURLs for CSGHub application
--
UPDATE application
SET redirect_uris = json_build_array(
    rtrim( replace(current_setting('session.external_endpoint', true), '''', ''), '/') || '/api/v1/callback/casdoor'
)::text
WHERE name = 'CSGHub';

--
-- Enable org Select for built-in application
--
UPDATE
    application
SET
    enable_sign_up = 'f',
    org_choice_mode = 'Select'
WHERE
    name = 'app-built-in';

--
DO $$
BEGIN
    UPDATE "user"
    SET
        password_type = (SELECT password_type FROM "user" WHERE name = 'root' LIMIT 1),
        password = (SELECT password FROM "user" WHERE name = 'root' LIMIT 1)
    WHERE
        name = 'admin'
        AND (password <> (SELECT password FROM "user" WHERE name = 'root' LIMIT 1)
             OR password_type <> (SELECT password_type FROM "user" WHERE name = 'root' LIMIT 1));

    RAISE NOTICE 'Admin password and type updated successfully';
END $$;

--
DO $$
DECLARE
    oauth_client_id text := current_setting('session.oauth_client_id', true);
    oauth_client_secret text := current_setting('session.oauth_client_secret', true);
    oauth_issuer text := current_setting('session.oauth_issuer', true);
BEGIN
    IF oauth_client_id IS NOT NULL AND oauth_client_id <> ''
       AND oauth_client_secret IS NOT NULL AND oauth_client_secret <> ''
       AND oauth_issuer IS NOT NULL AND oauth_issuer <> '' THEN
        UPDATE
            provider
        SET
            client_id = oauth_client_id,
            client_secret = oauth_client_secret,
            custom_auth_url = oauth_issuer || '/oauth/authorize',
            custom_token_url = oauth_issuer || '/oauth/token',
            custom_user_info_url = oauth_issuer || '/api/v4/user'
        WHERE
            name = 'GitLab_Provider';

        RAISE NOTICE 'GitLab provider updated successfully';
    ELSE
        RAISE NOTICE 'Incomplete OAuth configuration, skipping GitLab provider update';
    END IF;
END $$;

--
DO $$
DECLARE
    external_endpoint text := current_setting('session.external_endpoint', true);
    oauth_client_id text := current_setting('session.oauth_client_id', true);
    oauth_client_secret text := current_setting('session.oauth_client_secret', true);
    oauth_issuer text := current_setting('session.oauth_issuer', true);
BEGIN
    RAISE NOTICE 'Database update completed successfully!';
    RAISE NOTICE 'External endpoint: %', external_endpoint;
    RAISE NOTICE 'Password update for user admin';
    RAISE NOTICE 'OAuth update: %', CASE WHEN oauth_client_id IS NOT NULL AND oauth_client_id <> ''
                                           AND oauth_client_secret IS NOT NULL AND oauth_client_secret <> ''
                                           AND oauth_issuer IS NOT NULL AND oauth_issuer <> '' THEN 'Performed' ELSE 'Skipped' END;
END $$;