from enum import IntEnum
from pydantic import BaseModel, Field


class UserModel(BaseModel):
    uid: int
    name: str
    account_id: str

    def __eq__(self, value: object) -> bool:
        if self.__class__ == value.__class__:
            return self.uid == value.uid

        return super().__eq__(value)


class AuthenticationMethod(IntEnum):
    NONE = 0
    OPENPLANET = 1


class LoginModel(BaseModel):
    authentication: AuthenticationMethod
    username: str
    account_id: str
    token: str | None = Field(default=None)


class LoginResponseModel(UserModel):
    client_token: str
