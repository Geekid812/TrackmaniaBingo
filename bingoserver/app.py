from typing import Annotated
from fastapi import FastAPI, Depends

from models.channel import ChannelModel, NewChannelModel
from models.user import UserModel
from user import get_user

app = FastAPI()
channels: dict[str, ChannelModel] = {}


@app.get("/me")
def get_my_account(user: Annotated[UserModel, Depends(get_user)]) -> UserModel:
    return user


@app.get("/channels")
def get_channels() -> list[ChannelModel]:
    return [channel for channel in channels.values() if channel.public]


@app.put("/channels")
def create_channel(user: Annotated[UserModel, Depends(get_user)], new_channel: NewChannelModel) -> ChannelModel:
    channel = ChannelModel(name=new_channel.name, public=new_channel.public)

    channels[channel.id] = channel

    return channel
