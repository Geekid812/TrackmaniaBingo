from enum import IntEnum
from datetime import timedelta

from pydantic import BaseModel


class GamePlatform(IntEnum):
    NEXT = 0
    MP4 = 1
    TURBO = 2


class Medal(IntEnum):
    AUTHOR = 0
    GOLD = 1
    SILVER = 2
    BRONZE = 3
    NONE = 4


class GameRulesModel(BaseModel):
    platform: GamePlatform
    grid_width: int
    grid_height: int
    target_medal: Medal
    main_duration: timedelta
    nobingo_duration: timedelta
    b64_grid_pattern: str

    has_overtime: bool
    has_rerolls: bool
    has_competitve_patch: bool

    can_join_during_game: bool


class GridModel(BaseModel): ...


class CellEditModel(BaseModel): ...


class RunResultModel(BaseModel): ...
