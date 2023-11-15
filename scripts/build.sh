#!/bin/sh

set -e

./scripts/build-roblox-asset.sh .darklua.json build
./scripts/build-roblox-asset.sh .darklua-dev.json build/debug
./scripts/build-single-file.sh .darklua-bundle.json build
./scripts/build-single-file.sh .darklua-bundle-dev.json build/debug
