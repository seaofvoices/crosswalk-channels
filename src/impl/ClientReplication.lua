local Constants = require('./Constants')
local Teardown = require('@pkg/luau-teardown')
local readValue = require('./readValue')
local waitForeverForChild = require('./waitForeverForChild')

-- todo: once darklua can properly re-rexport the teardown type
-- replace `any` with `Teardown.Teardown`
type Teardown = any
type Fn<T> = (T) -> ()

export type ClientReplication = {
    setup: (self: ClientReplication, parent: Instance, player: Player) -> (),
    bind: <T>(self: ClientReplication, name: string, fn: Fn<T>) -> () -> (),
}

type Private = {
    _connections: { [string]: { Fn<any> } },
    _localContainer: Instance?,
    _localCounterContainer: Instance?,
    _globalContainer: Instance?,
    _globalCounterContainer: Instance?,
}
type ClientReplicationStatic = ClientReplication & Private & {
    new: () -> ClientReplication,
}

local ClientReplication: ClientReplicationStatic = {} :: any
local ClientReplicationMetatable = {
    __index = ClientReplication,
}

function ClientReplication.new(): ClientReplication
    local self: Private = {
        _connections = {},
        _localContainer = nil,
        _localCounterContainer = nil,
        _globalContainer = nil,
        _globalCounterContainer = nil,
    }

    return setmetatable(self, ClientReplicationMetatable) :: any
end

function ClientReplication:setup(parent: Instance, player: Player): Teardown
    local self: Private & ClientReplication = self :: any

    local globalContainer = parent:WaitForChild(Constants.GlobalContainerName) :: any
    local globalCounterContainer = parent:WaitForChild(Constants.CounterContainerName) :: any

    self._globalContainer = globalContainer
    self._globalCounterContainer = globalCounterContainer

    local function fireFns(container: Instance, name: string, fns: { Fn<any> })
        local currentValue = readValue(container, name)

        for _, fn in fns do
            task.spawn(fn, currentValue)
        end
    end

    local function updateValue(container: Instance, name: string)
        local fns = self._connections[name]
        if fns == nil or #fns == 0 then
            return
        end

        task.defer(fireFns, container, name, fns)
    end

    local localConnection = nil
    local disconnected = false

    task.spawn(function()
        local playerGui = waitForeverForChild(player, 'PlayerGui')
        local localContainer = waitForeverForChild(playerGui, Constants.LocalPlayerContainerName)
        local localCounterContainer = waitForeverForChild(playerGui, Constants.CounterContainerName)

        if disconnected then
            return
        end

        self._localContainer = localContainer
        self._localCounterContainer = localCounterContainer

        localConnection = localCounterContainer.AttributeChanged:Connect(
            function(attributeName: string)
                updateValue(localContainer, attributeName)
            end
        )

        for attributeName in localCounterContainer:GetAttributes() do
            updateValue(localContainer, attributeName)
        end
    end)

    return Teardown.join(
        globalCounterContainer.AttributeChanged:Connect(function(attributeName: string)
            updateValue(globalContainer, attributeName)
        end),
        function()
            disconnected = true
            if localConnection then
                Teardown.teardown(localConnection :: any)
            end
        end
    )
end

function ClientReplication:bind<T>(name: string, fn: Fn<T>): () -> ()
    local self: Private & ClientReplication = self :: any

    local connectionsForName = self._connections[name]
    if connectionsForName == nil then
        connectionsForName = {}
        self._connections[name] = connectionsForName
    end
    table.insert(connectionsForName, fn)

    local disconnected = false
    local function disconnect()
        if disconnected then
            if _G.DEV then
                error('attempt to disconnect signal twice')
            end
            return
        end
        local index = table.find(connectionsForName, fn)
        if index then
            table.remove(connectionsForName, index)
        end
    end

    local globalContainer = self._globalContainer
    local globalCounterContainer = self._globalCounterContainer
    local localContainer = self._localContainer
    local localCounterContainer = self._localCounterContainer

    if globalContainer and globalCounterContainer then
        local currentValue = if localCounterContainer
                and localContainer
                and localCounterContainer:GetAttribute(name) ~= nil
            then {
                value = readValue(localContainer, name),
            }
            elseif globalCounterContainer:GetAttribute(name) ~= nil then {
                value = readValue(globalContainer, name),
            }
            else nil

        if currentValue then
            task.spawn(fn, currentValue.value)
        end
    end

    return disconnect
end

return ClientReplication
