#!/usr/bin/python3
import requests
import argparse
import os
import platform
import json
import sqlite3
from datetime import datetime
from time import sleep
from pathlib import Path

USER_AGENT = f"mapcache (part of TrackmaniaBingo by Geekid#1871) / Python {platform.python_version()}"

parser = argparse.ArgumentParser(
    prog = 'mapcache',
    description = 'simple TrackmaniaExchange map metadata exporter.',
)

parser.add_argument('-o', '--output', help='output file', type=Path, default=Path('./out.db'))
parser.add_argument('-i', '--interval', help='interval between two requests in seconds (default: 10)', type=int, default=10)
parser.add_argument('-e', '--errinterval', help='interval before retrying after a failed request in seconds (default: 60)', type=int, default=60)
parser.add_argument('-l', '--limit', help='maps limit for a single request [20-100] (default: 50)', type=int, default=50)

args = parser.parse_args()

def log(*args, **kwargs):
    print(*((datetime.now().strftime('%H:%M:%S'),) + args), **kwargs)

def err(e):
    print('ERROR:', e)
    sleep(args.errinterval)

def include_track(map):
    return map["MapType"] == "TM_Race" and map["Downloadable"] and map["VehicleName"] == "CarSport"

def save_result(page, result):
    values = [
        (
            res["TrackID"],
            res["TrackUID"],
            res["UserID"],
            res["AuthorLogin"],
            res["Username"],
            res["Name"],
            res["GbxMapName"],
            res["DisplayCost"],
            res["AuthorTime"],
            res["UploadedAt"],
            res["UpdatedAt"],
            res["Tags"],
            res["StyleName"]
        )
        for res in result["results"] if include_track(res)
    ]
    cur.executemany("INSERT OR REPLACE INTO maps VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", values)
    conn.commit()

def create_db(cur):
    cur.execute("""
    CREATE TABLE IF NOT EXISTS "maps" (
        "tmxid"	INTEGER NOT NULL,
        "uid"	CHAR(28) UNIQUE,
        "userid"	INTEGER NOT NULL,
        "userlogin"	CHAR(23) NOT NULL,
        "username"	TEXT NOT NULL,
        "trackname"	TEXT NOT NULL,
        "gbxname"	TEXT NOT NULL,
        "coppers"	INTEGER NOT NULL,
        "authortime"	INTEGER NOT NULL,
        "uploaded"	TIMESTAMP NOT NULL,
        "updated"	TIMESTAMP NOT NULL,
        "tags"	TEXT,
        "style"	TEXT,
        PRIMARY KEY("tmxid")
    );
    """)

log('creating output file:', args.output)
conn = sqlite3.connect(args.output)
cur = conn.cursor()
create_db(cur)

page = 1
headers = {'user-agent': USER_AGENT}

while True:
    log(f'requesting page {page}...', end='')
    res = requests.get(
        f"https://trackmania.exchange/mapsearch2/search?api=on&page={page}&limit={args.limit}",
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
        if j['totalItemCount'] == 0:
            print('COMPLETE')
            break
    except KeyError as e:
        err(e)
        continue

    try:
        save_result(page, j)
    except Exception as e:
        err(e)
        # SQLite error: we should still move to the next page as the request was successful
        page += 1
        continue

    print('OK')
    sleep(args.interval)
    page += 1
