from typing import Annotated
from fastapi import FastAPI, Depends

from models.user import UserModel
from user import get_user

import db
import config
import channel
import game

app = FastAPI(title="Trackmania Bingo API", version=config.get(
    "version"), debug=config.is_development())
app.include_router(channel.router)
app.include_router(game.router)

db.init_database()


@app.get("/me")
def get_my_account(user: Annotated[UserModel, Depends(get_user)]) -> UserModel:
    return user
