-- Database version: 2
-- Created on: 2024-06-03
-- 
-- New player fields

ALTER TABLE players ADD COLUMN games_played INTEGER NOT NULL DEFAULT 0;
ALTER TABLE players ADD COLUMN games_won INTEGER NOT NULL DEFAULT 0;

-- TODO: update exisiting player tables
