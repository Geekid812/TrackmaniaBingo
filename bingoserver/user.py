from typing import Annotated, Optional
from functools import lru_cache

from fastapi import Header, HTTPException, status

import config
from models.user import UserModel
from models.channel import ChannelModel

system_token = config.get("keys.system_token")
tokens: dict[str, UserModel] = {}


def set_user_token(user: UserModel, token: str):
    for ktoken in tokens.keys():
        if tokens[ktoken] == user:
            tokens.pop(ktoken)

    tokens[token] = user


@lru_cache()
def get_user(x_token: Annotated[str, Header()]) -> UserModel:
    if system_token != "" and x_token == system_token:
        return UserModel(uid=0, name="Pit Crew", account_id="0")

    user = tokens.get(x_token)
    if not user:
        raise HTTPException(status_code=403, detail="token invalid")

    return user


def get_user_from_id(uid: int) -> UserModel:
    user = try_get_user_from_id(uid)

    if not user:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, f"player with uid {uid} not found"
        )

    return user


def try_get_user_from_id(uid: int) -> Optional[UserModel]:
    return None


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
