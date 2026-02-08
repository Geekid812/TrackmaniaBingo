#!/usr/bin/python3
import requests
import argparse
import platform
import json
import sqlite3
import urllib.parse
from datetime import datetime
from time import sleep
from pathlib import Path

USER_AGENT = f"mapcache script (part of TrackmaniaBingo by @geekid) / Python {platform.python_version()}"

parser = argparse.ArgumentParser(
    prog = 'mapcache',
    description = 'simple TrackmaniaExchange map metadata exporter.',
)

parser.add_argument('-o', '--output',      help='output file', type=Path, default=Path('./out.db'))
parser.add_argument('-i', '--interval',    help='interval between two requests in seconds (default: 10)', type=int, default=10)
parser.add_argument('-e', '--errinterval', help='interval before retrying after a failed request in seconds (default: 60)', type=int, default=60)
parser.add_argument('-c', '--count',       help='number of results per request (TMX max: 1000). Higher is faster; lower is gentler on the API. (default: 100)', type=int, default=100)
parser.add_argument('--after',             help='start pagination after this TMX MapId (debug/resume). Note: must be a MapId that appears in /api/maps (unlisted/unreleased maps may return empty). When omitted, starts from the latest maps.', type=int, default=None)
parser.add_argument('--max-pages',         help='stop after fetching N pages (debug). When omitted, runs until the API reports completion.', type=int, default=None)
parser.add_argument('--timeout',           help='HTTP request timeout in seconds (default: 30).', type=int, default=30)
parser.add_argument('--stats',             help='print database stats at the end of the run.', action='store_true')

args = parser.parse_args()

def log(*args, **kwargs):
    print(*((datetime.now().strftime('%H:%M:%S'),) + args), **kwargs)

def err(e):
    print('ERROR:', e)
    sleep(args.errinterval)

def include_track(map):
    return map["MapType"] == "TM_Race" and map["Vehicle"] == 1

def save_result(page, result):
    values = []
    for res in result:
        if not include_track(res):
            continue

        authors = res.get("Authors") or []
        if not authors:
            continue

        user = (authors[0] or {}).get("User") or {}
        userid = user.get("UserId")
        username = user.get("Name")
        if userid is None or username is None:
            continue

        medals = res.get("Medals") or {}
        author_time = medals.get("Author")
        gold_time = medals.get("Gold")
        silver_time = medals.get("Silver")
        bronze_time = medals.get("Bronze")
        if None in (author_time, gold_time, silver_time, bronze_time):
            continue

        tags = res.get("Tags") or []
        values.append(
            (
                res.get("MapId"),
                res.get("MapUid"),
                res.get("OnlineMapId"),
                userid,
                username,
                res.get("Name"),
                res.get("GbxMapName"),
                author_time,
                gold_time,
                silver_time,
                bronze_time,
                res.get("UploadedAt"),
                res.get("UpdatedAt"),
                ",".join([str(tag.get("TagId")) for tag in tags if tag and tag.get("TagId") is not None]),
                (tags[0] or {}).get("Name") if tags else None,
            )
        )

    cur.executemany("INSERT OR REPLACE INTO maps VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", values)
    conn.commit()

def create_db(cur):
    cur.execute("""
    CREATE TABLE IF NOT EXISTS "maps" (
        "tmxid"	INTEGER NOT NULL,
        "uid"	CHAR(28) UNIQUE,
        "webservices_id" TEXT UNIQUE,
        "userid"	INTEGER NOT NULL,
        "username"	TEXT NOT NULL,
        "track_name"	TEXT NOT NULL,
        "gbx_name"	TEXT NOT NULL,
        "author_time"	INTEGER NOT NULL,
        "gold_time"	INTEGER NOT NULL,
        "silver_time"	INTEGER NOT NULL,
        "bronze_time"	INTEGER NOT NULL,
        "uploaded_at"	TIMESTAMP NOT NULL,
        "updated_at"	TIMESTAMP NOT NULL,
        "tags"	TEXT,
        "style" TEXT,
        PRIMARY KEY("tmxid")
    );
    """)

log('creating output file:', args.output)
conn = sqlite3.connect(args.output)
cur = conn.cursor()
create_db(cur)

page = 1
next_param = f"&after={args.after}" if args.after is not None else ""
prev_after = None
headers = {'user-agent': USER_AGENT}
fields = urllib.parse.quote_plus("MapId,MapUid,OnlineMapId,Authors[],Name,GbxMapName,Medals.Author,Medals.Gold,Medals.Silver,Medals.Bronze,Vehicle,UploadedAt,UpdatedAt,MapType,Tags[]")

while True:
    page_count = min(max(args.count, 1), 1000)

    log(f'requesting page {page}...', end='')
    try:
        res = requests.get(
            f"https://trackmania.exchange/api/maps?fields={fields}&count={page_count}{next_param}",
            headers=headers,
            timeout=args.timeout,
        )
    except requests.RequestException as e:
        err(e)
        continue

    try:
        res.raise_for_status()
    except requests.HTTPError as e:
        err(e)
        continue

    try:
        j = json.loads(res.text)
    except json.JSONDecodeError as e:
        err(e)
        continue

    try:
        results = j.get("Results") or []
        if not results:
            err("TMX returned an empty page of results unexpectedly.")
            break

        save_result(page, j["Results"])
        if not j["More"]:
            print('COMPLETE')
            break
    
        after = results[-1]["MapId"]
        if after == prev_after:
            if page_count < 1000:
                err(
                    f"Pagination cursor did not advance (after={after}). "
                    f"Increasing --count to 1000 and retrying (was {page_count})."
                )
                args.count = 1000
                continue

            err(f"Pagination cursor did not advance (after={after}). Aborting to avoid an infinite loop.")
            break

        prev_after = after
        next_param = f"&after={after}"
    except Exception as e:
        err(e)
        break

    print('OK')
    sleep(args.interval)
    page += 1

    if args.max_pages is not None and page > args.max_pages:
        print('STOPPED (max-pages)')
        break

if args.stats:
    cur.execute("SELECT COUNT(*) FROM maps")
    total = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM maps WHERE author_time <= 180000")
    under_3m = cur.fetchone()[0]
    cur.execute("SELECT MIN(uploaded_at), MAX(uploaded_at) FROM maps")
    uploaded_range = cur.fetchone()
    cur.execute("SELECT COUNT(DISTINCT userid) FROM maps")
    distinct_users = cur.fetchone()[0]
    print('STATS:')
    print('  total_maps:', total)
    print('  author_time<=180000:', under_3m)
    print('  uploaded_at_range:', uploaded_range)
    print('  distinct_userid:', distinct_users)
