from contextlib import asynccontextmanager
from typing import Annotated
from fastapi import FastAPI, Depends, HTTPException, status

from models.user import UserModel
from user import get_user

import auth
import db
import config
import channel
import game


@asynccontextmanager
async def lifecycle(app: FastAPI):
    await auth.init_client()
    yield  # Run the app


app = FastAPI(
    title="Trackmania Bingo API",
    version=config.get("version"),
    debug=config.is_development(),
    lifespan=lifecycle,
)
app.include_router(auth.router)
app.include_router(channel.router)
app.include_router(game.router)

db.init_database()


@app.get("/me")
def get_my_account(user: Annotated[UserModel, Depends(get_user)]) -> db.PlayerSchema:
    player = db.get_player(user.uid)

    if not player:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, f"/me profile with uid {user.uid} not found"
        )

    return player
