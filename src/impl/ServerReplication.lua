local Constants = require('./Constants')
local createFolder = require('./createFolder')
local getPlayerSetup = require('./getPlayerSetup')
local matchAttributeName = require('./matchAttributeName')
local writeValue = require('./writeValue')

export type ServerReplication = {
    setup: (self: ServerReplication, parent: Instance) -> (),
    send: (self: ServerReplication, name: string, value: unknown) -> (),
    sendLocal: (self: ServerReplication, player: Player, name: string, value: unknown) -> (),
}

type Private = {
    _container: Folder?,
    _counterContainer: Folder?,
    _globalCounter: { [string]: number },
    _playerCounters: { [Player]: { [string]: number } },

    _incrementGlobalCounter: (self: ServerReplication, name: string) -> number,
    _incrementPlayerCounter: (self: ServerReplication, player: Player, name: string) -> number,
}
type ServerReplicationStatic = ServerReplication & Private & {
    new: () -> ServerReplication,
}

local ServerReplication: ServerReplicationStatic = {} :: any
local ServerReplicationMetatable = {
    __index = ServerReplication,
}

function ServerReplication.new(): ServerReplication
    local self: Private = {
        _container = nil,
        _globalCounter = {},
        -- playerCounters is a weaktable to avoid preserving
        -- pointers to Player instances
        _playerCounters = setmetatable({}, { __mode = 'k' }) :: any,

        -- define methods to satisfy Luau typechecking
        _incrementGlobalCounter = nil :: any,
        _incrementPlayerCounter = nil :: any,
    }

    return setmetatable(self, ServerReplicationMetatable) :: any
end

function ServerReplication:setup(parent: Instance)
    local self: Private & ServerReplication = self :: any

    self._container = createFolder(Constants.GlobalContainerName, parent)
    self._counterContainer = createFolder(Constants.CounterContainerName, parent)
end

function ServerReplication:send(name: string, value: unknown)
    local self: Private & ServerReplication = self :: any

    if _G.DEV and (self._container == nil or self._counterContainer == nil) then
        error('unable to send data before ServerReplication is setup')
    end

    if _G.DEV and not matchAttributeName(name) then
        error(
            string.format(
                'invalid channel name `%s` (must be composed of letters, numbers and '
                    .. 'underscores with a maximum of 100 characters)',
                name
            )
        )
    end

    local counterValue = self:_incrementGlobalCounter(name)
    writeValue(self._container :: Folder, name, value)
    writeValue(self._counterContainer :: Folder, name, counterValue)
end

function ServerReplication:sendLocal(player: Player, name: string, value: unknown)
    local self: Private & ServerReplication = self :: any

    if _G.DEV and not matchAttributeName(name) then
        error(
            string.format(
                'invalid channel name `%s` (must be composed of letters, numbers and '
                    .. 'underscores with a maximum of 100 characters)',
                name
            )
        )
    end

    task.spawn(function()
        local playerSetup = getPlayerSetup(player)

        if playerSetup ~= nil then
            local counterValue = self:_incrementPlayerCounter(player, name)

            if _G.DEV then
                local success, err: any = pcall(writeValue, playerSetup.values, name, value)
                if not success then
                    error(`unable to send value on local channel '{name}': {err}`)
                end
            else
                writeValue(playerSetup.values, name, value)
            end
            writeValue(playerSetup.counters, name, counterValue)
        end
    end)
end

function ServerReplication:_incrementGlobalCounter(name: string): number
    local self: Private & ServerReplication = self :: any
    local value = 1 + (self._globalCounter[name] or 0)
    self._globalCounter[name] = value
    return value
end

function ServerReplication:_incrementPlayerCounter(player: Player, name: string): number
    local self: Private & ServerReplication = self :: any

    local counters = self._playerCounters[player]
    if counters == nil then
        counters = {}
        self._playerCounters[player] = counters
    end

    local value = 1 + (counters[name] or 0)
    counters[name] = value
    return value
end

return ServerReplication
