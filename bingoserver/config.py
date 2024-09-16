import tomllib
import os
import shutil

if not os.path.isfile("config.toml"):
    shutil.copyfile("data/config.default.toml", "config.toml")

with open("config.toml", "rb") as f:
    config = tomllib.load(f)


def get(key: str):
    return config[key]
