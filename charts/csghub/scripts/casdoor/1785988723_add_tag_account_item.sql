--
-- Append the "Tag" field to the OpenCSG organization's account_items
--
-- The Tag entry is already declared in init_data.json, but casdoor's
-- initDataNewOnly=true means existing organizations are NOT re-seeded on
-- redeploy, so deployments created before Tag was added lack it in the DB.
-- This appends the entry idempotently for the OpenCSG organization.
--

SELECT now() as "Execute Timestamp";

SELECT pg_catalog.set_config('search_path', 'public', false);

DO $$
DECLARE
    org_name text := 'OpenCSG';
    tag_item jsonb := '{"name":"Tag","visible":true,"viewRule":"Public","modifyRule":"Admin","regex":""}';
    current_items jsonb;
BEGIN
    SELECT account_items::jsonb INTO current_items
    FROM organization
    WHERE name = org_name;

    IF current_items IS NULL THEN
        RAISE NOTICE 'Organization % not found, skipping', org_name;
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1 FROM jsonb_array_elements(current_items) item
        WHERE item->>'name' = 'Tag'
    ) THEN
        RAISE NOTICE 'Tag already present in % account_items, skipping', org_name;
    ELSE
        UPDATE organization
        SET account_items = (current_items || tag_item)::text
        WHERE name = org_name;

        RAISE NOTICE 'Tag appended to % account_items', org_name;
    END IF;
END $$;
