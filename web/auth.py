from dataclasses import dataclass
import requests
import functools
from secrets import token_urlsafe
from flask import (
    Blueprint,
    current_app,
    redirect,
    url_for,
    request,
    session,
    make_response,
    g,
)

bp = Blueprint("auth", __name__, url_prefix="/auth")


@dataclass
class User:
    username: str
    account_id: str


def get_oauth_parameters() -> (str, str, str):
    identifier = current_app.config["UBISOFT_OAUTH_ID"]
    secret = current_app.config["UBISOFT_OAUTH_SECRET"]
    redirect_uri = current_app.config["ROOT_URL"] + url_for("auth.callback")

    return identifier, secret, redirect_uri


def get_authorized_player(access_token: str) -> (str, str):
    headers = {"Authorization": f"Bearer {access_token}"}

    req = requests.get("https://api.trackmania.com/api/user", headers=headers)
    req.raise_for_status()

    player = req.json()
    return player["displayName"], player["accountId"]


@bp.get("/callback")
def callback():
    code = request.args.get("code")
    state = request.args.get("state")
    session_state = session.get("state")

    if session_state is None:
        response = make_response("Authentication error: Invalid session.", 401)
        response.headers["Content-Type"] = "text/plaintext"
        return response

    # CSRF check: ensure the state parameter matches with the session state
    if session_state != state:
        response = make_response("Authentication error: Invalid state parameter.", 401)
        response.headers["Content-Type"] = "text/plaintext"
        return response

    authorize_url = "https://api.trackmania.com/api/access_token"
    identifier, secret, redirect_uri = get_oauth_parameters()
    form_parameters = {
        "grant_type": "authorization_code",
        "client_id": identifier,
        "client_secret": secret,
        "code": code,
        "redirect_uri": redirect_uri,
    }

    req = requests.post(authorize_url, data=form_parameters)
    req.raise_for_status()
    credentials = req.json()

    username, account_id = get_authorized_player(credentials["access_token"])
    session["displayName"] = username
    session["accountId"] = account_id

    return redirect(url_for("index"))


@bp.get("/login")
def login():
    state = token_urlsafe(16)
    session["state"] = state

    identifier, _, redirect_uri = get_oauth_parameters()
    url = f"https://api.trackmania.com/oauth/authorize?response_type=code&client_id={identifier}&redirect_uri={redirect_uri}&state={state}"
    return redirect(url)


@bp.get("/logout")
def logout():
    session.pop("displayName", None)
    session.pop("accountId", None)

    return redirect(url_for("index"))


@bp.before_app_request
def load_user():
    username = session.get("displayName")
    account_id = session.get("accountId")
    admin_account_id = current_app.config["ADMIN_ACCOUNT_ID"]

    if username is None:
        g.user = None
        g.admin = False
    else:
        g.user = User(username, account_id)
        g.admin = account_id == admin_account_id

def admin_restricted(view):
    @functools.wraps(view)
    def wrapped_view(**kwargs):
        if not g.admin:
            return redirect(url_for('auth.login'))

        return view(**kwargs)

    return wrapped_view
