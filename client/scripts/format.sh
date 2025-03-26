#!/usr/bin/env sh
set -eEuo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: format.sh <directory>"
    exit 1
fi

find "$1" -name '*.as' -exec clang-format -style=file -i {} \;
