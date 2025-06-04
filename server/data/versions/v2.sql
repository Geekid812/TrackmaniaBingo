-- Database version: 2
-- Created on: 2024-06-03
-- 
-- New player fields
ALTER TABLE players DROP COLUMN score;
ALTER TABLE players DROP COLUMN deviation;
CREATE VIEW IF NOT EXISTS player_summary AS
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
    ) as games_won
FROM players;
