import tomllib
import os
import shutil

if not os.path.isfile("config.toml"):
    shutil.copyfile("data/config.default.toml", "config.toml")

with open("config.toml", "rb") as f:
    config = tomllib.load(f)


def get(key: str):
    paths = key.split(".")
    value = config
    for path in paths:
        value = value[path]

    return value


def is_development() -> bool:
    return get("environment") == "dev"
