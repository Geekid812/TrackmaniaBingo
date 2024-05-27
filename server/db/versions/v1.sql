-- Database version: 1
-- Created on: 2024-05-26
-- 
-- Combination of all prior versions up until version 1.5.0

CREATE TABLE players (
	uid	INTEGER NOT NULL,
	account_id	CHAR(37) NOT NULL UNIQUE,
	username	TEXT NOT NULL,
	created_at	TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    score INTEGER NOT NULL DEFAULT 1000,
    deviation INTEGER NOT NULL DEFAULT 300,
    country_code CHAR(3) NOT NULL DEFAULT "WOR",
    title TEXT,
	client_token CHAR(32),
	PRIMARY KEY("uid" AUTOINCREMENT)
);

CREATE TABLE matches (
	uid	CHAR(12) NOT NULL UNIQUE,
	started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	ended_at	TIMESTAMP,
    daily_timedate TEXT,
	PRIMARY KEY("uid")
);

CREATE TABLE matches_players (
	player_uid    INTEGER NOT NULL,
	match_uid	CHAR(12) NOT NULL,
	outcome	CHAR(1),
	FOREIGN KEY(player_uid) REFERENCES players(uid)
	FOREIGN KEY(match_uid) REFERENCES matches(uid)
    PRIMARY KEY(player_uid, match_uid)
);
