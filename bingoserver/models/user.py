from pydantic import BaseModel


class UserModel(BaseModel):
    uid: int
    name: str
    account_id: str
