from typing import Annotated

from fastapi import Header, HTTPException

from models.user import UserModel


def get_user(x_token: Annotated[str, Header()]) -> UserModel:
    if x_token == "secret":
        return UserModel(uid=0, name="Player 0", account_id="0")

    raise HTTPException(status_code=403, detail="Token invalid")
