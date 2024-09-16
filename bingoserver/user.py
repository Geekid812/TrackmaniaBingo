from typing import Annotated, Optional
from functools import lru_cache

from fastapi import Header, HTTPException, status

from models.user import UserModel
from models.channel import ChannelModel


@lru_cache()
def get_user(x_token: Annotated[str, Header()]) -> UserModel:
    if x_token == "secret":
        return UserModel(uid=0, name="Player 0", account_id="0")

    raise HTTPException(status_code=403, detail="Token invalid")


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
