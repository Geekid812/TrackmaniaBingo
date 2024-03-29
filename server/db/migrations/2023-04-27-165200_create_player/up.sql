CREATE TABLE players (
	uid	INTEGER NOT NULL,
	account_id	CHAR(37) NOT NULL UNIQUE,
	username	TEXT NOT NULL,
	created_at	TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    score INTEGER NOT NULL DEFAULT 1000,
    deviation INTEGER NOT NULL DEFAULT 300,
    country_code CHAR(3) NOT NULL DEFAULT "WOR",
	client_token CHAR(32),
	PRIMARY KEY("uid" AUTOINCREMENT)
);