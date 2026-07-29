#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$repo_root"

find . -maxdepth 3 -type f -name '*.sh' -not -path '*/.git/*' -print0 |
    xargs -0 -r bash -n
printf "OK shell syntax\\n"
