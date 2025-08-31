-- Database version: 3
-- Created on: 2025-03-26
-- 
-- Remove client tokens in database
ALTER TABLE players DROP COLUMN client_token;
