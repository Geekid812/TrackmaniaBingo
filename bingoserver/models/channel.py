from typing import Optional, Annotated
from annotated_types import Len
from uuid import uuid4

from pydantic import BaseModel, Field

from models.user import UserModel
from models.game import GameRulesModel


class PlayerModel(UserModel): ...


class NewTeamModel(BaseModel):
    name: str
    color: Annotated[list[int], Len(min_length=3, max_length=3)]


class TeamModel(NewTeamModel):
    id: int


class PopulatedTeamModel(TeamModel):
    members: list[PlayerModel]


class ChannelParamsModel(BaseModel):
    name: str
    public: bool
    game_rules: GameRulesModel


class ChannelModel(ChannelParamsModel):
    host: UserModel
    id: str = Field(default_factory=lambda: uuid4().hex)
    code: Optional[str] = Field(default=None)
    players: list[UserModel] = Field(default_factory=list)
    teams: list[PopulatedTeamModel] = Field(default_factory=list)


class ChannelStatusModel(BaseModel): ...


class ThreadModel(BaseModel): ...
