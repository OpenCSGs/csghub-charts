-- Copyright OpenCSG, Inc. All Rights Reserved.
-- SPDX-License-Identifier: APACHE-2.0

-- Initialize the _migrations tracking table used to record which migration
-- scripts have been applied. Each successfully executed script inserts its
-- own filename into this table, and subsequent runs skip scripts that are
-- already recorded.

CREATE TABLE IF NOT EXISTS _migrations (
  name TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ DEFAULT NOW()
);