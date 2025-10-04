--
-- Record Timestamp
--
SELECT now() as "Execute Timestamp";

--
-- PostgreSQL database dump
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
-- Set Default Schema for All Tables
--

SELECT pg_catalog.set_config('search_path', 'public', false);

--
-- Seed Data for Name: space_resources; Type: TABLE DATA; Schema: public; Owner: csghub
--

INSERT INTO public.space_resources (id, name, resources, cluster_id)
SELECT
    1,
    'CPU basic · 0.5 vCPU · 1 GB',
    '{ "cpu": { "type": "Intel", "num": "0.5" }, "memory": "1Gi" }',
    COALESCE((SELECT cluster_id FROM public.cluster_infos LIMIT 1), '')
UNION ALL
SELECT
    2,
    'CPU basic · 2 vCPU · 4 GB',
    '{ "cpu": { "type": "Intel", "num": "2" }, "memory": "4Gi" }',
    COALESCE((SELECT cluster_id FROM public.cluster_infos LIMIT 1), '')
ON CONFLICT (id)
DO UPDATE SET
    name = EXCLUDED.name,
    resources = EXCLUDED.resources,
    cluster_id = CASE
        WHEN EXCLUDED.cluster_id != '' THEN EXCLUDED.cluster_id
        ELSE space_resources.cluster_id
    END;

--
-- Create Trigger Function
--
CREATE OR REPLACE FUNCTION update_space_resources_cluster_id()
RETURNS TRIGGER AS $$
BEGIN
    -- Update cluster_id for id 1,2
    UPDATE public.space_resources
    SET cluster_id = NEW.cluster_id
    WHERE cluster_id = ''
    AND id IN (1, 2);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--
-- Create Trigger
--
DROP TRIGGER IF EXISTS trg_update_space_resources ON public.cluster_infos;

CREATE TRIGGER trg_update_space_resources
    AFTER INSERT ON public.cluster_infos
    FOR EACH ROW
    EXECUTE FUNCTION update_space_resources_cluster_id();

--
-- Name: space_resources_id_seq; Type: SEQUENCE SET; Schema: public; Owner: csghub
--
SELECT pg_catalog.setval('public.space_resources_id_seq', (
    SELECT MAX(id) FROM public.space_resources), TRUE);
