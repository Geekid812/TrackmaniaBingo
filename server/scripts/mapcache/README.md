# Mapcache Script

This script generates the `db/mapcache.db` SQLite database used by the Trackmania Bingo server.

It fetches map metadata from the TrackmaniaExchange API, filtering for compatible maps, and stores the map metadata in a local database. The script paginates through the API at a configurable rate (see below), collecting map data for use as the map selection pool in the server.

## Usage
From the `server/scripts/mapcache` directory, run:

```bash
pip install --user requests
python3 main.py
```

This will create or update the `db/mapcache.db` file in the project root. Make sure the `db/` directory exists before running the script.

You can then start the server as usual.

## Command Line Arguments

- `-o`, `--output`   : Output file path for the generated SQLite database (default: `./out.db`). To generate the database in the correct location for the server, use `-o ../../db/mapcache.db`.
- `-i`, `--interval` : Interval (in seconds) between two API requests (default: 10).
- `-e`, `--errinterval` : Interval (in seconds) before retrying after a failed request (default: 60).
