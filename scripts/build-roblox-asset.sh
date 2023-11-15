#!/bin/sh

set -e

DARKLUA_CONFIG=$1
BUILD_OUTPUT=$2
CODE_OUTPUT=roblox/$DARKLUA_CONFIG

if [ ! -d node_modules ]; then
    rm -rf $CODE_OUTPUT/node_modules
    yarn install
    yarn prepare
fi

rojo sourcemap channels.project.json -o sourcemap.json

rm -rf $CODE_OUTPUT/src
darklua process --config $DARKLUA_CONFIG src $CODE_OUTPUT/src

if [ ! -d $CODE_OUTPUT/node_modules ]; then
    darklua process --config $DARKLUA_CONFIG node_modules $CODE_OUTPUT/node_modules
fi

cp -r channels.project.json $CODE_OUTPUT/

mkdir -p $BUILD_OUTPUT

rojo build $CODE_OUTPUT/channels.project.json -o $BUILD_OUTPUT/channels.rbxm
