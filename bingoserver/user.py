from typing import Annotated, Optional
from functools import lru_cache

from fastapi import Header, HTTPException, status

import config
from db import get_player
from models.user import UserModel
from models.channel import ChannelModel

system_token = config.get("keys.system_token")
tokens: dict[str, UserModel] = {}


def set_user_token(user: UserModel, token: str):
    tokens[token] = user


@lru_cache()
def get_user(x_token: Annotated[str, Header()] = None) -> UserModel:
    if x_token == None:
        raise HTTPException(status_code=401, detail="X-Token header missing")
    if system_token != "" and x_token == system_token:
        return UserModel(uid=0, name="Pit Crew", account_id="0")

    user = tokens.get(x_token)
    if not user:
        raise HTTPException(status_code=403, detail="token invalid")

    return user


@lru_cache
def get_user_from_id(uid: int) -> UserModel:
    user = try_get_user_from_id(uid)

    if not user:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, f"player with uid {uid} not found"
        )

    return user


def try_get_user_from_id(uid: int) -> Optional[UserModel]:
    player = get_player(uid)
    if not player:
        return None

    return UserModel(uid=player.uid, name=player.username, account_id=player.account_id)


def is_system_user(user: UserModel) -> bool:
    return user.uid == 0


def is_channel_operator(user: UserModel, channel: ChannelModel) -> bool:
    return is_system_user(user) or user == channel.host


def require_channel_operator(user: UserModel, channel: ChannelModel):
    if not is_channel_operator(user, channel):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "user is not a channel operator")


def require_self_operation(user: UserModel, other: UserModel):
    if not is_system_user(user) and user != other:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "operation not allowed on this user"
        )
