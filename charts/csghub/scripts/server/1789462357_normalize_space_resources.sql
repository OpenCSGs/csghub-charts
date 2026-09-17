--
-- Normalize the seeded space_resources rows
--
-- The seed in 1779675341 inserts `resources` as a compact JSON string with
-- jsonb key ordering, while the standard rows use a 2-space pretty layout
-- ordered cpu -> memory -> gpu -> replicas and carry `replicas` (plus
-- `mem_size` on GPU rows). This script rewrites the seeded rows to that
-- layout and sets their `scenarios` field:
--   id 1,2 (CPU basic)   -> 161
--   id 3,4 (NVIDIA 4090) -> 974957576239
--
-- Rows are matched by id + name so an id collision with an unrelated
-- resource cannot be rewritten. GPU rows match by name pattern because
-- quick_install.sh rewrites the seeded '4090' to the cluster's actual GPU
-- name (e.g. 'NVIDIA A100 * 1 · ...'); the existing gpu.type and
-- nvidia_name values are preserved when rebuilding the JSON.
--

--
-- Record Timestamp
--
SELECT now() as "Execute Timestamp";

--
-- Set Default Schema
--
SELECT pg_catalog.set_config('search_path', 'public', false);

DO $$
DECLARE
    updated integer;

    -- Templates sit flush-left on purpose: the string stored in `resources`
    -- must not carry the SQL indentation. The %s slots are filled by format().
    cpu_tpl text := $tpl${
  "cpu": {
    "type": %s,
    "num": %s
  },
  "memory": %s,
  "replicas": %s
}$tpl$;

    gpu_tpl text := $tpl${
  "cpu": {
    "type": %s,
    "num": %s
  },
  "memory": %s,
  "gpu": {
    "type": %s,
    "num": %s,
    "resource_name": %s,
    "mem_size": %s,
    "labels": {
      "nvidia.com/nvidia_name": %s
    }
  },
  "replicas": %s
}$tpl$;
BEGIN
    --
    -- CPU rows
    --
    UPDATE public.space_resources
    SET scenarios = 161,
        resources = format(
            cpu_tpl,
            COALESCE(to_jsonb(resources::jsonb->'cpu'->>'type'), 'null'),
            COALESCE(to_jsonb(resources::jsonb->'cpu'->>'num'), 'null'),
            COALESCE(to_jsonb(resources::jsonb->>'memory'), 'null'),
            COALESCE(resources::jsonb->>'replicas', '1'))
    WHERE id IN (1, 2)
      AND name IN ('CPU basic · 0.5 vCPU · 1 GB', 'CPU basic · 2 vCPU · 4 GB');
    GET DIAGNOSTICS updated = ROW_COUNT;
    RAISE NOTICE 'CPU space_resources normalized: % row(s)', updated;

    --
    -- GPU rows
    --
    UPDATE public.space_resources
    SET scenarios = 974957576239,
        resources = format(
            gpu_tpl,
            COALESCE(to_jsonb(resources::jsonb->'cpu'->>'type'), 'null'),
            COALESCE(to_jsonb(resources::jsonb->'cpu'->>'num'), 'null'),
            COALESCE(to_jsonb(resources::jsonb->>'memory'), 'null'),
            COALESCE(to_jsonb(resources::jsonb->'gpu'->>'type'), 'null'),
            COALESCE(to_jsonb(resources::jsonb->'gpu'->>'num'), 'null'),
            COALESCE(to_jsonb(resources::jsonb->'gpu'->>'resource_name'), 'null'),
            COALESCE(to_jsonb(resources::jsonb->'gpu'->>'mem_size'), '"20480"'),
            COALESCE(to_jsonb(resources::jsonb->'gpu'->'labels'->>'nvidia.com/nvidia_name'), 'null'),
            COALESCE(resources::jsonb->>'replicas', '1'))
    WHERE id IN (3, 4)
      AND (name LIKE 'NVIDIA % * 1 · 4 vCPU · 8 GB'
           OR name LIKE '2 * NVIDIA % * 8 · 4 vCPU · 8 GB');
    GET DIAGNOSTICS updated = ROW_COUNT;
    RAISE NOTICE 'GPU space_resources normalized: % row(s)', updated;
END $$;
