import os
from flask import Flask, render_template
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.config.from_prefixed_env()
app.config["ROOT_URL"] = os.environ.get("ROOT_URL")
app.config["INTERNAL_API_URL"] = os.environ.get("INTERNAL_API_URL")
app.config["ADMIN_ACCOUNT_ID"] = os.environ.get("ADMIN_ACCOUNT_ID")
app.config["UBISOFT_OAUTH_ID"] = os.environ.get("UBISOFT_OAUTH_ID")
app.config["UBISOFT_OAUTH_SECRET"] = os.environ.get("UBISOFT_OAUTH_SECRET")
app.config["SEND_FILE_MAX_AGE_DEFAULT"] = 60

from . import auth, room

app.register_blueprint(auth.bp)
app.register_blueprint(room.bp)

@app.get("/")
def index():
    return render_template("index.html")
