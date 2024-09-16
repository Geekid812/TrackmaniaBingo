from datetime import datetime

import sqlalchemy
from sqlalchemy.sql.functions import now
from sqlmodel import SQLModel, Field, Session

import config

sqlite_file_name = "database.db"
sqlite_url = f"sqlite:///{sqlite_file_name}"

engine = sqlalchemy.create_engine(sqlite_url, echo=config.is_development())


def init_database():
    SQLModel.metadata.create_all(engine)


class PlayerSchema(SQLModel, table=True):
    uid: int | None = Field(default=None, primary_key=True)
    account_id: str
    username: str
    created_at: datetime = Field(default=now())
    country_code: str = Field(default="WOR")
    games_played: int = Field(default=0)
    title: str | None = Field(default=None)
