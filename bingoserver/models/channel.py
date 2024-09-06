from typing import Optional
from uuid import uuid4

from pydantic import BaseModel, Field


class NewChannelModel(BaseModel):
    name: str
    public: bool


class ChannelModel(NewChannelModel):
    id: str = Field(default_factory=lambda: uuid4().hex)
    code: Optional[str] = Field(default=None)
