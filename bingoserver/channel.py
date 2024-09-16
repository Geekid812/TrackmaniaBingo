from typing import Annotated, Any, Optional
from fastapi import APIRouter, Depends, Body, status, HTTPException, status

from models.channel import (
    ChannelModel,
    ChannelParamsModel,
    ThreadModel,
    TeamModel,
    NewTeamModel,
    ChannelStatusModel,
)
from models.user import UserModel
from models.events import EventModel, ChannelEvent, PlayerEvent
from user import (
    get_user,
    get_user_from_id,
    require_channel_operator,
    require_self_operation,
)
from message import MessageQueue

channels: dict[str, ChannelModel] = {}
messagers: dict[str, MessageQueue] = {}
toplevel_messager = MessageQueue()


def get_channel(channel_id: str) -> ChannelModel:
    channel = channels.get(channel_id)
    if not channel:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, f"channel with ID {channel_id} not found"
        )

    return channel


def get_messager(channel: ChannelModel) -> MessageQueue:
    return messagers[channel.id]


router = APIRouter(prefix="/channels", tags=["channel"])


@router.get("")
def get_channels() -> list[ChannelModel]:
    return [channel for channel in channels.values() if channel.public]


@router.get("/resolve")
def resolve_join_code(code: str) -> ChannelModel: ...


@router.put("", status_code=status.HTTP_201_CREATED)
def create_channel(
    user: Annotated[UserModel, Depends(get_user)], new_channel: ChannelParamsModel
) -> ChannelModel:
    channel = ChannelModel(
        name=new_channel.name,
        public=new_channel.public,
        game_rules=new_channel.game_rules,
        host=user,
    )

    channels[channel.id] = channel
    messagers[channel.id] = MessageQueue()
    toplevel_messager.broadcast(ChannelEvent(event="ChannelCreated", channel=channel))

    return channel


@router.get("/{channel_id}")
def get_channel(channel: ChannelModel = Depends(get_channel)) -> ChannelModel:
    return channel


@router.patch("/{channel_id}")
def edit_channel(
    config: Annotated[ChannelParamsModel, Body()],
    channel: ChannelModel = Depends(get_channel),
    user: UserModel = Depends(get_user),
):
    require_channel_operator(user, channel)

    channel.name = config.name
    channel.public = config.public
    channel.game_rules = config.game_rules

    get_messager(channel).broadcast(
        ChannelEvent(event="ChannelModified", channel=channel)
    )


@router.delete("/{channel_id}")
def delete_channel(
    message: Annotated[str, Body()] = None,
    channel=Depends(get_channel),
    user=Depends(get_user),
):
    require_channel_operator(user, channel)

    channels.pop(channel.id, None)
    toplevel_messager.broadcast(ChannelEvent(event="ChannelDeleted", channel=channel))


@router.put("/{channel_id}/players")
def add_player(
    target_uid: int,
    channel: ChannelModel = Depends(get_channel),
    user: UserModel = Depends(get_user),
):
    target = get_user_from_id(target_uid)
    require_self_operation(user, target)

    if user in channel.players:
        raise HTTPException(
            status.HTTP_304_NOT_MODIFIED, "user already joined the channel"
        )

    channel.players.append(user)
    get_messager(channel).broadcast(PlayerEvent(event="PlayerAdded", user=user))


@router.delete("/{channel_id}/players")
def remove_player(
    target_uid: int,
    channel: ChannelModel = Depends(get_channel),
    user: UserModel = Depends(get_user),
):
    target = get_user_from_id(target_uid)
    require_self_operation(user, target)

    if user not in channel.players:
        raise HTTPException(status.HTTP_304_NOT_MODIFIED, "user is not in the channel")

    channel.players.remove(user)
    get_messager(channel).broadcast(PlayerEvent(event="PlayerRemoved", user=user))


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


@router.get("/{channel_id}/poll")
async def poll_channel_events(
    channel: ChannelModel = Depends(get_channel), user: UserModel = Depends(get_user)
) -> list[EventModel]:
    return await get_messager(channel).get(user.uid)
