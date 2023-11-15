[![checks](https://github.com/seaofvoices/crosswalk-channels/actions/workflows/test.yml/badge.svg)](https://github.com/seaofvoices/crosswalk-channels/actions/workflows/test.yml)
![version](https://img.shields.io/github/package-json/v/seaofvoices/crosswalk-channels)
[![GitHub top language](https://img.shields.io/github/languages/top/seaofvoices/crosswalk-channels)](https://github.com/luau-lang/luau)
![license](https://img.shields.io/npm/l/crosswalk-channels)
![npm](https://img.shields.io/npm/dt/crosswalk-channels)

# Channels

A crosswalk shared module to easily send data **one way** from the server to client(s). Values can be sent to individual players or to all players.

**IMPORTANT**

This module will make use of `PlayerGui` to store instances, so to prevent them from being deleted when the character reloads, you must disable the `ResetPlayerGuiOnSpawn` property of `StarterGui`. Disable this property by running this line in the command bar:

```lua
game.StarterGui.ResetPlayerGuiOnSpawn = false
```

# Installation

## Using the npm package

Add `crosswalk-channels` in your dependencies:

```bash
yarn add crosswalk-channels
```

Or if you are using `npm`:

```bash
npm install crosswalk-channels
```

## Roblox asset

Put the Channels.rbxm file inside your crosswalk **shared modules** folder.

# License

This plugin for crosswalk is available under the MIT license. See [LICENSE.txt](LICENSE.txt) for details.

# API

## Server API

### Send

Publish values on a channel that any player can listen to.

```lua
Channels.Send(channelName: string, value: unknown)
```

### SendLocal

Publish values on a channel **for a single player**.

```lua
Channels.SendLocal(player: Player, channelName: string, value: unknown)
```

## Client API

### Bind

```lua
Bind<T>(channelName: string, func: (T) -> ()): () -> ()
```

- Each client can connect to values that are sent to its own player or to all players.
- A function will be returned by the `Bind` call to disconnect

```lua
local disconnect = Channels.Bind("timer", function(newValue)

end)

-- ... when needed, you can disconnect the callback by calling the `disconnect` function

disconnect()
```
