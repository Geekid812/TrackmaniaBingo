from pydantic import BaseModel


class UserModel(BaseModel):
    uid: int
    name: str
    account_id: str

    def __eq__(self, value: object) -> bool:
        if self.__class__ == value.__class__:
            return self.uid == value.uid

        return super().__eq__(value)
