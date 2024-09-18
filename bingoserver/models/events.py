from pydantic import BaseModel

from models.user import UserModel
from models.channel import ChannelModel
from models.channel import TeamModel


class EventModel(BaseModel):
    event: str


class ChannelEvent(EventModel):
    channel: ChannelModel


class PlayerEvent(EventModel):
    user: UserModel


class TeamEvent(EventModel):
    team: TeamModel
