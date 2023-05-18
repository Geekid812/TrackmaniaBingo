CREATE TABLE "matches" (
	uid	CHAR(12) NOT NULL UNIQUE,
	started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	ended_at	TIMESTAMP,
	PRIMARY KEY("uid")
);

CREATE TABLE "matches_players" (
	player_uid    INTEGER NOT NULL,
	match_uid	CHAR(12) NOT NULL,
	outcome	CHAR(1),
	FOREIGN KEY(player_uid) REFERENCES players(uid)
	FOREIGN KEY(match_uid) REFERENCES matches(uid)
    PRIMARY KEY(player_uid, match_uid)
);