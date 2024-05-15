#!/bin/sh

set -e

scripts/build-single-file.sh .darklua-bundle.json build/channels.lua
scripts/build-single-file.sh .darklua-bundle-dev.json build/debug/channels.lua
scripts/build-roblox-model.sh .darklua.json build/channels.rbxm
scripts/build-roblox-model.sh .darklua-dev.json build/debug/channels.rbxm
