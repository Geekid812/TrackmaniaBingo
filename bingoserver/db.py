from datetime import datetime

from pydantic import field_serializer
import sqlalchemy
from sqlalchemy.sql.functions import now
from sqlmodel import SQLModel, Field, Session, select

import config

sqlite_file_name = "database.db"
sqlite_url = f"sqlite:///{sqlite_file_name}"

engine = sqlalchemy.create_engine(sqlite_url, echo=config.is_development())


def init_database():
    SQLModel.metadata.create_all(engine)


class PlayerSchema(SQLModel, table=True):
    uid: int | None = Field(default=None, primary_key=True)
    account_id: str = Field(unique=True)
    username: str
    created_at: datetime = Field(default=now())
    country_code: str = Field(default="WOR")
    games_played: int = Field(default=0)
    title: str | None = Field(default=None)

    @field_serializer("created_at", when_used="json")
    def dt_serialize(self, dt: datetime) -> int:
        return int(dt.timestamp())


def get_player(uid: int) -> PlayerSchema | None:
    with Session(engine) as session:
        stmt = select(PlayerSchema).where(PlayerSchema.uid == uid)
        res = session.exec(stmt)
        return res.one_or_none()
