from typing import Annotated
from fastapi import APIRouter, Depends, Body, status

from models.channel import (
    ChannelModel,
    NewChannelModel,
    ThreadModel,
    TeamModel,
    NewTeamModel,
    ChannelStatusModel,
    ChannelConfigModel,
)
from models.user import UserModel
from user import get_user

channels: dict[str, ChannelModel] = {}


def get_channel(channel_id: str) -> ChannelModel: ...


router = APIRouter(prefix="/channels", tags=["channel"])


@router.get("")
def get_channels() -> list[ChannelModel]:
    return [channel for channel in channels.values() if channel.public]


@router.get("/resolve")
def resolve_join_code(code: str) -> ChannelModel: ...


@router.put("", status_code=status.HTTP_201_CREATED)
def create_channel(
    user: Annotated[UserModel, Depends(get_user)], new_channel: NewChannelModel
) -> ChannelModel:
    channel = ChannelModel(name=new_channel.name, public=new_channel.public)

    channels[channel.id] = channel

    return channel


@router.get("/{channel_id}")
def get_channel(channel=Depends(get_channel)) -> ChannelModel:
    return channel


@router.patch("/{channel_id}")
def edit_channel(
    config: Annotated[ChannelConfigModel, Body()],
    channel=Depends(get_channel),
    user=Depends(get_user),
):
    raise NotImplementedError()


@router.delete("/{channel_id}")
def delete_channel(
    message: Annotated[str, Body()] = None,
    channel=Depends(get_channel),
    user=Depends(get_user),
):
    raise NotImplementedError()


@router.put("/{channel_id}/players")
def add_player(target_uid: int, channel=Depends(get_channel), user=Depends(get_user)):
    raise NotImplementedError()


@router.delete("/{channel_id}/players")
def remove_player(
    target_uid: int, channel=Depends(get_channel), user=Depends(get_user)
):
    raise NotImplementedError()


@router.get("/{channel_id}/chat/{thread_id}")
def read_chat(
    thread_id: int, channel=Depends(get_channel), user=Depends(get_user)
) -> ThreadModel:
    raise NotImplementedError()


@router.post("/{channel_id}/chat/{thread_id}")
def write_chat(
    thread_id: int,
    message: Annotated[str, Body()],
    channel=Depends(get_channel),
    user=Depends(get_user),
):
    raise NotImplementedError()


@router.put("/{channel_id}/teams", status_code=status.HTTP_201_CREATED)
def create_team(
    team: Annotated[NewTeamModel, Body()],
    channel=Depends(get_channel),
    user=Depends(get_user),
) -> TeamModel:
    raise NotImplementedError()


@router.patch("/{channel_id}/teams/{team_id}")
def edit_team(team_id: int, channel=Depends(get_channel), user=Depends(get_user)):
    raise NotImplementedError()


@router.put("/{channel_id}/teams/{team_id}/members")
def add_team_member(
    team_id: int, target_uid: int, channel=Depends(get_channel), user=Depends(get_user)
):
    raise NotImplementedError()


@router.delete("/{channel_id}/teams/{team_id}/members")
def remove_team_member(
    team_id: int, target_uid: int, channel=Depends(get_channel), user=Depends(get_user)
):
    raise NotImplementedError()


@router.delete("/{channel_id}/teams/{team_id}")
def delete_team(team_id: int, channel=Depends(get_channel), user=Depends(get_user)):
    raise NotImplementedError()


@router.post("/{channel_id}")
def update_status(
    status: Annotated[ChannelStatusModel, Body()],
    channel=Depends(get_channel),
    user=Depends(get_user),
):
    raise NotImplementedError()
