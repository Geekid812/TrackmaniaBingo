from typing import Annotated

from fastapi import Header, HTTPException, status

from models.user import UserModel
from models.channel import ChannelModel


def get_user(x_token: Annotated[str, Header()]) -> UserModel:
    if x_token == "secret":
        return UserModel(uid=0, name="Player 0", account_id="0")

    raise HTTPException(status_code=403, detail="Token invalid")


def is_system_user(user: UserModel) -> bool:
    return user.uid == 0


def is_channel_operator(user: UserModel, channel: ChannelModel) -> bool:
    return is_system_user(user) or user == channel.host


def require_channel_operator(user: UserModel, channel: ChannelModel):
    if not is_channel_operator(user, channel):
        raise HTTPException(status.HTTP_403_FORBIDDEN,
                            "user is not a channel operator")
