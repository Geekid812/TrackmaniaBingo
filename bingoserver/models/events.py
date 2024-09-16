from pydantic import BaseModel

from models.user import UserModel
from models.channel import ChannelModel, ChannelParamsModel


class EventModel(BaseModel):
    event: str


class ChannelEvent(EventModel):
    channel: ChannelModel


class PlayerEvent(BaseModel):
    user: UserModel
