#!/bin/bash
# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
#
# SPDX-License-Identifier: MIT
#
# Pull the macOS SDK from the private package ghcr.io/v-sekai-fire/apple-sdks (pushed with ORAS), check its checksum,
# unpack it and print the flake override. The SDK is not redistributable: keep it outside git.
#   usage: tools/fetch-apple-sdk.sh <dir>
#   token: $GHCR_TOKEN (Actions: GITHUB_TOKEN, with the package's Actions access granted to this repository),
#          else `gh auth token`
set -euo pipefail
DIR=${1:?directory required}
REF=${APPLE_SDK_REF:-ghcr.io/v-sekai-fire/apple-sdks:v0.0.0-20261102000912-39773a6404cf}
TOKEN=${GHCR_TOKEN:-$(gh auth token)}
mkdir -p "$DIR"; cd "$DIR"
printf '%s' "$TOKEN" | oras login ghcr.io -u "${GHCR_USER:-token}" --password-stdin >/dev/null
oras pull "$REF"
grep MacOSX SHA256SUMS | sha256sum -c -
tar -xf MacOSX26.5.sdk.tar.xz
echo "--override-input appleSdk path:$PWD/MacOSX26.5.sdk"
