#!/usr/bin/python3
import requests
import argparse
import os
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

parser.add_argument('-o', '--output', help='output file', type=Path, default=Path('./out.db'))
parser.add_argument('-i', '--interval', help='interval between two requests in seconds (default: 10)', type=int, default=10)
parser.add_argument('-e', '--errinterval', help='interval before retrying after a failed request in seconds (default: 60)', type=int, default=60)

args = parser.parse_args()

def log(*args, **kwargs):
    print(*((datetime.now().strftime('%H:%M:%S'),) + args), **kwargs)

def err(e):
    print('ERROR:', e)
    sleep(args.errinterval)

def include_track(map):
    return map["MapType"] == "TM_Race" and map["Vehicle"] == 1

def save_result(page, result):
    values = [
        (
            res["MapId"],
            res["MapUid"],
            res["OnlineMapId"],
            res["Authors"][0]["User"]["UserId"],
            res["Authors"][0]["User"]["Name"],
            res["Name"],
            res["GbxMapName"],
            res["Medals"]["Author"],
            res["Medals"]["Gold"],
            res["Medals"]["Silver"],
            res["Medals"]["Bronze"],
            res["UploadedAt"],
            res["UpdatedAt"],
            ",".join([str(tag["TagId"]) for tag in res["Tags"]]),
            res["Tags"][0]["Name"]
        )
        for res in result if include_track(res)
    ]
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
next_param = ""
headers = {'user-agent': USER_AGENT}
fields = urllib.parse.quote_plus("MapId,MapUid,OnlineMapId,Authors[],Name,GbxMapName,Medals.Author,Medals.Gold,Medals.Silver,Medals.Bronze,Vehicle,UploadedAt,UpdatedAt,MapType,Tags[]")

while True:
    log(f'requesting page {page}...', end='')
    res = requests.get(
        f"https://trackmania.exchange/api/maps?fields={fields}{next_param}",
        headers=headers
    )

    try:
        res.raise_for_status()
    except requests.HTTPError as e:
        err(e)
        continue

    try:
        j = json.loads(res.text)
    except json.JSONError as e:
        err(e)
        continue

    try:
        save_result(page, j["Results"])
        if not j["More"]:
            print('COMPLETE')
            break
    
        next_param = f"&after={j["Results"][-1]["MapId"]}"
    except Exception as e:
        err(e)
        # SQLite error
        break

    print('OK')
    sleep(args.interval)
    page += 1
