#!/bin/bash
# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
#
# SPDX-License-Identifier: MIT
#
# Fetch the macOS SDK from the private release of V-Sekai-fire/repository-apple-sdks, check its checksum, unpack it and
# print the flake override. The SDK is not redistributable: keep it outside git.
#   usage: tools/fetch-apple-sdk.sh <dir>        token: $APPLE_SDK_TOKEN, else bao-mint-github
set -euo pipefail
DIR=${1:?directory required}
REPO=V-Sekai-fire/repository-apple-sdks
TOKEN=${APPLE_SDK_TOKEN:-$(bao-mint-github --owner V-Sekai-fire --token-only)}
mkdir -p "$DIR"; cd "$DIR"
api() { curl -fsSL -H "Authorization: Bearer $TOKEN" -H "Accept: $2" "$1"; }
REL=$(api "https://api.github.com/repos/$REPO/releases/latest" application/vnd.github+json)
id() { printf '%s' "$REL" | python3 -I -c "import sys,json; print([a['id'] for a in json.load(sys.stdin)['assets'] if a['name']=='$1'][0])"; }
api "https://api.github.com/repos/$REPO/releases/assets/$(id SHA256SUMS)" application/octet-stream > SHA256SUMS
api "https://api.github.com/repos/$REPO/releases/assets/$(id MacOSX26.5.sdk.tar.xz)" application/octet-stream > MacOSX26.5.sdk.tar.xz
grep MacOSX SHA256SUMS | sha256sum -c -
tar -xf MacOSX26.5.sdk.tar.xz
echo "--override-input appleSdk path:$PWD/MacOSX26.5.sdk"
