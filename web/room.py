from dataclasses import dataclass
import requests
from secrets import token_urlsafe
from pydantic import BaseModel
from datetime import datetime, timezone, timedelta
from flask import (
    Blueprint,
    current_app,
    redirect,
    url_for,
    request,
    session,
    make_response,
    g,
    render_template
)

from .datatypes import RoomConfiguration, MatchConfiguration, PlayerProfile

bp = Blueprint("rooms", __name__, url_prefix="/rooms")

class RoomTeam(BaseModel):
    id: int
    name: str
    color: list[int]
    members: list[PlayerProfile]

class RoomModel(BaseModel):
    config: RoomConfiguration
    matchconfig: MatchConfiguration
    join_code: str
    teams: list[RoomTeam]
    created_at: datetime

def stringify_config(matchconfig: MatchConfiguration) -> str:
    return f"""\
    <i class=\"fa\">&#xf00a;</i> {matchconfig.grid_size}x{matchconfig.grid_size}
    <i class=\"fa\">&#xf279;</i> {matchconfig.selection.name.capitalize()}
    <i class=\"fa\">&#xf140;</i> {matchconfig.target_medal.name.capitalize()}
    <i class=\"fa\">&#xf254;</i> {'∞' if matchconfig.time_limit.total_seconds() <= 0. else matchconfig.time_limit}
    """

def color_to_string(color: list[int]) -> str:
    return f"{color[0]:02x}{color[1]:02x}{color[2]:02x}"

def player_team_map(room: RoomModel) -> (str, str):
    return [(p.name, color_to_string(t.color)) for t in room.teams for p in t.members]

def timedelta_verbify(delta: timedelta) -> str:
    days, rem = divmod(delta.total_seconds(), 86400)
    hours, rem = divmod(rem, 3600)
    minutes, seconds = divmod(rem, 60)
    if seconds < 1:seconds = 1
    locals_ = locals()
    magnitudes_str = ("{n} {magnitude}".format(n=int(locals_[magnitude]), magnitude=magnitude)
                      for magnitude in ("days", "hours", "minutes", "seconds") if locals_[magnitude])
    return ", ".join(magnitudes_str)

def get_rooms() -> list[RoomModel]:
    base_url = current_app.config["INTERNAL_API_URL"]
    
    req = requests.get(base_url + "/dir/rooms")
    req.raise_for_status()
    return [RoomModel(**d) for d in req.json()]

@bp.get("/")
def list_rooms():
    rooms = get_rooms()
    rooms.sort(key=lambda room: room.created_at)
    return render_template("rooms.html", rooms=rooms, stringify_config=stringify_config, player_team_map=player_team_map, len=len, now=datetime.now(timezone.utc), timedelta_verbify=timedelta_verbify, strftime=datetime.strftime)

