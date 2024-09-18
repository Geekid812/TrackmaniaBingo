import secrets

from aiohttp import ClientSession, FormData, ClientResponseError
from fastapi import APIRouter, Body, HTTPException, status
from sqlmodel import Session, select

import config
import db
from db import PlayerSchema
from user import set_user_token
from models.user import UserModel, LoginModel, LoginResponseModel, AuthenticationMethod

VALIDATION_URL = "https://openplanet.dev/api/auth/validate"
TMIO_API_PLAYER_URL = "https://trackmania.io/api/player"

router = APIRouter(prefix="/auth", tags=["auth"])
http_client: ClientSession = None


async def init_client():
    global http_client
    http_client = ClientSession(
        headers={"user-agent": config.get("network.user-agent")}
    )


@router.post("/login")
async def login(body: LoginModel = Body()) -> LoginResponseModel:
    if body.authentication == AuthenticationMethod.NONE:
        if not config.is_development():
            raise HTTPException(
                status.HTTP_401_UNAUTHORIZED, "authentication method not allowed"
            )

        username, account_id = body.username, body.account_id
    else:
        openplanet_key = config.get("keys.openplanet")
        if openplanet_key == "KEY":
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE,
                "Openplanet authentication is not configured",
            )

        token = body.token
        if not token:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "token not provided")

        async with http_client.get(
            VALIDATION_URL, data=FormData({"token": token, "secret": openplanet_key})
        ) as response:
            response.raise_for_status()

            res: dict = await response.json()
            if "error" in res.keys():
                raise HTTPException(
                    status.HTTP_400_BAD_REQUEST, "authentication error: " + res["error"]
                )

            username, account_id = res["username"], res["account_id"]

    try:
        country_code = await get_player_country_code(account_id)
    except (KeyError, ClientResponseError):
        country_code = None

    player = update_user(username, account_id, country_code)

    client_token = secrets.token_hex(16)
    set_user_token(
        UserModel(uid=player.uid, name=player.username, account_id=player.account_id),
        client_token,
    )

    return LoginResponseModel(
        uid=player.uid,
        name=player.username,
        account_id=player.account_id,
        client_token=client_token,
    )


async def get_player_country_code(account_id: str) -> str:
    async with http_client.get(TMIO_API_PLAYER_URL + "/" + account_id) as response:
        response.raise_for_status()

        res: dict = await response.json()
        zone = res["trophies"]["zone"]

        def is_country_code(code: str) -> bool:
            return len(code) == 3 and code.isupper()

        while not is_country_code(zone["flag"]):
            zone = zone["parent"]

        return zone["flag"]


def update_user(
    username: str, account_id: str, country_code: str = None
) -> PlayerSchema:
    with Session(db.engine) as session:
        stmt = select(PlayerSchema).where(PlayerSchema.account_id == account_id)
        result = session.exec(stmt)

        player = result.one()
        if player:
            player.username = username

            if country_code:
                player.country_code = country_code
        else:
            player = PlayerSchema(
                username=username, account_id=account_id, country_code=country_code
            )

        session.add(player)
        session.commit()
