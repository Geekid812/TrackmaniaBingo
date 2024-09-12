from typing import Annotated

from fastapi import APIRouter, Depends, Body

from models.game import GridModel, CellEditModel, RunResultModel

from channel import get_channel
from user import get_user

router = APIRouter(prefix="/channels/{channel_id}", tags=["game"])


@router.get("/grid")
def get_playing_grid(channel=Depends(get_channel)) -> GridModel:
    raise NotImplementedError()


@router.patch("/grid")
def edit_cell(
    location: int,
    edit_data: Annotated[CellEditModel, Body()],
    channel=Depends(get_channel),
    user=Depends(get_user),
):
    raise NotImplementedError()


@router.post("/records")
def post_record(
    location: int,
    run_result: Annotated[RunResultModel, Body()],
    channel=Depends(get_channel),
    user=Depends(get_user),
):
    raise NotImplementedError()
