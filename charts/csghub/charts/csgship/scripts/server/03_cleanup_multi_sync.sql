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
-- Cleanup Data for Multi-Sync Type: TABLE DATA; Schema: public; Owner: csghub
--

CREATE OR REPLACE FUNCTION cleanup_multi_sync_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_start_time TIMESTAMP := clock_timestamp();
    v_operation_start_time TIMESTAMP;
    v_deleted_count INTEGER;
    v_total_deleted_count INTEGER := 0;
    v_execution_time INTERVAL;
    v_table_names TEXT[] := ARRAY['models', 'datasets', 'codes', 'mcp_servers', 'files'];
    v_table_name TEXT;
    v_max_name_length INTEGER := 15;
BEGIN
    -- Log function start
    RAISE NOTICE '===========================================================';
    RAISE NOTICE 'Multi-Sync Data Cleanup Started: %', v_total_start_time;
    RAISE NOTICE '===========================================================';

    -- Delete all records from sync_versions table
    v_operation_start_time := clock_timestamp();
    DELETE FROM sync_versions;
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    v_total_deleted_count := v_total_deleted_count + v_deleted_count;
    v_execution_time := clock_timestamp() - v_operation_start_time;
    RAISE NOTICE '✓ %: % rows deleted (% ms)',
                 RPAD('sync_versions', v_max_name_length),
                 LPAD(v_deleted_count::TEXT, 4),
                 LPAD(ROUND(EXTRACT(EPOCH FROM v_execution_time) * 1000, 3)::TEXT, 8);

    -- Delete namespaces where path starts with 'CSG_'
    v_operation_start_time := clock_timestamp();
    DELETE FROM namespaces
    WHERE mirrored = true
    AND path LIKE 'CSG\_%' ESCAPE '\';
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    v_total_deleted_count := v_total_deleted_count + v_deleted_count;
    v_execution_time := clock_timestamp() - v_operation_start_time;
    RAISE NOTICE '✓ %: % rows deleted (% ms)',
                 RPAD('namespaces', v_max_name_length),
                 LPAD(v_deleted_count::TEXT, 4),
                 LPAD(ROUND(EXTRACT(EPOCH FROM v_execution_time) * 1000, 3)::TEXT, 8);

    -- Delete users where username starts with 'CSG_'
    v_operation_start_time := clock_timestamp();
    DELETE FROM users
    WHERE username LIKE 'CSG\_%' ESCAPE '\'
    AND id IN (
        SELECT user_id
        FROM namespaces
        WHERE mirrored = true
        AND path LIKE 'CSG\_%' ESCAPE '\'
    );
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    v_total_deleted_count := v_total_deleted_count + v_deleted_count;
    v_execution_time := clock_timestamp() - v_operation_start_time;
    RAISE NOTICE '✓ %: % rows deleted (% ms)',
                 RPAD('users', v_max_name_length),
                 LPAD(v_deleted_count::TEXT, 4),
                 LPAD(ROUND(EXTRACT(EPOCH FROM v_execution_time) * 1000, 3)::TEXT, 8);

    -- Delete records from repository-dependent tables
    FOREACH v_table_name IN ARRAY v_table_names
    LOOP
        v_operation_start_time := clock_timestamp();
        EXECUTE format(
            'DELETE FROM %I
            WHERE repository_id IN (
                SELECT id
                FROM repositories
                WHERE source = ''opencsg''
                AND path LIKE ''CSG\_%%'' ESCAPE ''\''
            )',
            v_table_name
        );
        GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
        v_total_deleted_count := v_total_deleted_count + v_deleted_count;
        v_execution_time := clock_timestamp() - v_operation_start_time;
        RAISE NOTICE '✓ %: % rows deleted (% ms)',
                     RPAD(v_table_name, v_max_name_length),
                     LPAD(v_deleted_count::TEXT, 4),
                     LPAD(ROUND(EXTRACT(EPOCH FROM v_execution_time) * 1000, 3)::TEXT, 8);
    END LOOP;

    -- Finally delete repositories where path starts with 'CSG_'
    v_operation_start_time := clock_timestamp();
    DELETE FROM repositories
    WHERE source = 'opencsg'
    AND path LIKE 'CSG\_%' ESCAPE '\';
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    v_total_deleted_count := v_total_deleted_count + v_deleted_count;
    v_execution_time := clock_timestamp() - v_operation_start_time;
    RAISE NOTICE '✓ %: % rows deleted (% ms)',
                 RPAD('repositories', v_max_name_length),
                 LPAD(v_deleted_count::TEXT, 4),
                 LPAD(ROUND(EXTRACT(EPOCH FROM v_execution_time) * 1000, 3)::TEXT, 8);

    -- Log completion message with execution time
    v_execution_time := clock_timestamp() - v_total_start_time;
    RAISE NOTICE '===========================================================';
    RAISE NOTICE 'Cleanup Summary:';
    RAISE NOTICE '- Total rows deleted: %', LPAD(v_total_deleted_count::TEXT, 7);
    RAISE NOTICE '- Total execution time: % ms',
                 LPAD(ROUND(EXTRACT(EPOCH FROM v_execution_time) * 1000, 3)::TEXT, 8);
    RAISE NOTICE 'Multi-Sync data cleanup completed successfully';
    RAISE NOTICE '===========================================================';
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Multi-Sync data cleanup failed: %', SQLERRM;
END;
$$;

-- Add comprehensive comment
COMMENT ON FUNCTION cleanup_multi_sync_data() IS
'Cleans up all Multi-Sync (CSG) related data in proper order to maintain referential integrity.
Deletes: sync_versions, mirrored namespaces, associated users, models, datasets, codes,
MCP servers, files, and finally repositories.';