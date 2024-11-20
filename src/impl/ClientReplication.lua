local Signal = require('@pkg/luau-signal')
local Teardown = require('@pkg/luau-teardown')

local Constants = require('./Constants')
local compareData = require('./compareData')
local waitForeverForChild = require('./waitForeverForChild')

type Signal<T...> = Signal.Signal<T...>
type Teardown = Teardown.Teardown

type Fn<T> = (T) -> ()

export type ClientReplication = {
    setOptions: (self: ClientReplication, options: ClientReplicationOptions) -> (),
    setup: (self: ClientReplication, parent: Instance, player: Player) -> (),
    bind: <T>(self: ClientReplication, name: string, fn: Fn<T>) -> () -> (),
    override: <T>(self: ClientReplication, name: string, value: T, expiration: number?) -> (),
}

type Private = {
    _isSetup: boolean,
    _race: boolean,
    _defaultExpiration: number,
    _channelSignals: { [string]: Signal<unknown> },
    _lastTimeStamps: { [string]: number },
    _lastData: { [string]: unknown },
    _overrides: { [string]: { remainingLife: number, value: unknown } },
}

export type ClientReplicationOptions = {
    race: boolean?,
    defaultExpiration: number?,
}

local DEFAULT_RACE_OPTIONS = false
local DEFAULT_EXPIRATION = 1.5

type ClientReplicationStatic = ClientReplication & Private & {
    new: (options: ClientReplicationOptions?) -> ClientReplication,
}

local ClientReplication: ClientReplicationStatic = {} :: any
local ClientReplicationMetatable = {
    __index = ClientReplication,
}

function ClientReplication.new(options: ClientReplicationOptions?): ClientReplication
    local options: ClientReplicationOptions = if options == nil then {} else options

    local self: Private = {
        _isSetup = false,
        _race = if options.race == nil then DEFAULT_RACE_OPTIONS else options.race,
        _defaultExpiration = options.defaultExpiration or DEFAULT_EXPIRATION,
        _channelSignals = {},
        _lastTimeStamps = {},
        _lastData = {},
        _overrides = {},
    }

    return setmetatable(self, ClientReplicationMetatable) :: any
end

function ClientReplication:setOptions(options: ClientReplicationOptions)
    local self: Private & ClientReplication = self :: any

    if self._isSetup then
        if _G.DEV then
            error('unable to update options after ClientReplication is setup')
        end
        return
    end

    if options.race ~= nil then
        self._race = options.race
    end
end

function ClientReplication:setup(parent: Instance, _player: Player): Teardown
    local self: Private & ClientReplication = self :: any

    if self._isSetup then
        if _G.DEV then
            error('attempt to setup ClientReplication twice')
        end
        return
    end
    self._isSetup = true

    local function receiveData(timeStamp: number, channelName: string, data: unknown)
        if timeStamp <= (self._lastTimeStamps[channelName] or 0) then
            return
        end

        local override = self._overrides[channelName]
        self._overrides[channelName] = nil

        if override ~= nil and compareData(override.value, data) then
            return
        end

        if compareData(self._lastData[channelName], data) then
            return
        end

        self._lastTimeStamps[channelName] = timeStamp
        self._lastData[channelName] = data

        local signal = self._channelSignals[channelName]

        if signal ~= nil then
            signal:fire(data)
        end
    end

    local unreliableRemote =
        waitForeverForChild(parent, Constants.FastEventName) :: UnreliableRemoteEvent
    local reliableRemote = waitForeverForChild(parent, Constants.EventName) :: RemoteEvent

    return Teardown.join(
        function()
            self._isSetup = false
        end,
        reliableRemote.OnClientEvent:Connect(function(packedPayloads)
            for _, payload in packedPayloads do
                receiveData(payload[1], payload[2], payload[3])
            end
        end) :: any,
        if self._race
            then unreliableRemote.OnClientEvent:Connect(
                function(timeStamp: number, channelName: string, data: unknown)
                    receiveData(timeStamp, channelName, data)
                    unreliableRemote:FireServer(channelName, timeStamp)
                end
            ) :: any
            else nil
    )
end

function ClientReplication:bind<T>(name: string, fn: Fn<T>): () -> ()
    local self: Private & ClientReplication = self :: any

    local signal = self._channelSignals[name]
    if signal == nil then
        signal = Signal.new()
        self._channelSignals[name] = signal
    end

    local disconnect = signal:connect(fn :: any):disconnectOnceFn()

    if self._lastTimeStamps[name] ~= nil then
        task.spawn(fn, self._lastData[name] :: any)
    end

    return disconnect
end

function ClientReplication:override<T>(name: string, value: T, expiration: number?)
    local self: Private & ClientReplication = self :: any

    local override = { remainingLife = expiration or self._defaultExpiration, value = value }

    self._overrides[name] = override

    task.delay(expiration, function()
        if self._overrides[name] == override then
            self._overrides[name] = nil

            local signal = self._channelSignals[name]
            if signal then
                signal:fire(self._lastData[name])
            end
        end
    end)
end

return ClientReplication
