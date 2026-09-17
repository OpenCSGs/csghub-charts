-- Copyright OpenCSG, Inc. All Rights Reserved.
-- SPDX-License-Identifier: APACHE-2.0

-- Backup dataflow tables by creating snapshot copies with date suffix,
-- then truncate the original tables so the application can reinitialize
-- them with a clean schema. VACUUM reclaims the disk space after truncation.

-- Snapshot: collection_tasks
CREATE TABLE IF NOT EXISTS collection_tasks_20260608 AS SELECT * FROM collection_tasks;
TRUNCATE TABLE collection_tasks CASCADE;
VACUUM collection_tasks;

-- Snapshot: data_format_tasks
CREATE TABLE IF NOT EXISTS data_format_tasks_20260608 AS SELECT * FROM data_format_tasks;
TRUNCATE TABLE data_format_tasks CASCADE;
VACUUM data_format_tasks;

-- Snapshot: datasources
CREATE TABLE IF NOT EXISTS datasources_20260608 AS SELECT * FROM datasources;
TRUNCATE TABLE datasources CASCADE;
VACUUM datasources;

-- Snapshot: deletion_status
CREATE TABLE IF NOT EXISTS deletion_status_20260608 AS SELECT * FROM deletion_status;
TRUNCATE TABLE deletion_status CASCADE;
VACUUM deletion_status;

-- Snapshot: job
CREATE TABLE IF NOT EXISTS job_20260608 AS SELECT * FROM job;
TRUNCATE TABLE job CASCADE;
VACUUM job;

-- Snapshot: workers
CREATE TABLE IF NOT EXISTS workers_20260608 AS SELECT * FROM workers;
TRUNCATE TABLE workers CASCADE;
VACUUM workers;