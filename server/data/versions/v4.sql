-- Database version: 4
-- Created on: 2025-08-31
-- 
-- Create MVP
ALTER TABLE matches
ADD COLUMN mvp_player_uid INTEGER REFERENCES players(uid);
DROP VIEW IF EXISTS player_summary;
CREATE VIEW player_summary AS
SELECT uid,
    account_id,
    username,
    created_at,
    (
        SELECT max(ended_at)
        FROM matches
            JOIN matches_players ON matches.uid = matches_players.match_uid
        WHERE matches_players.player_uid = players.uid
    ) as last_played_at,
    country_code,
    title,
    (
        SELECT count(*)
        FROM matches_players
        WHERE player_uid = players.uid
    ) as games_played,
    (
        SELECT count(*)
        FROM matches_players
        WHERE player_uid = players.uid
            AND outcome = 'W'
    ) as games_won,
    (
        SELECT count(*)
        FROM matches
        WHERE mvp_player_uid = players.uid
    ) as mvp_count
FROM players;
