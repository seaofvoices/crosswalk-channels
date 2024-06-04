local Players = game:GetService('Players')

local Teardown = require('@pkg/luau-teardown')

local Constants = require('./Constants')
local matchAttributeName = require('./matchAttributeName')

export type ServerReplication = {
    setup: (self: ServerReplication, parent: Instance) -> () -> (),
    registerPlayer: (self: ServerReplication, player: Player) -> (),
    unregisterPlayer: (self: ServerReplication, player: Player) -> (),
    send: (self: ServerReplication, name: string, value: unknown) -> (),
    sendLocal: (self: ServerReplication, player: Player, name: string, value: unknown) -> (),
}

type ChannelData = { [string]: { value: unknown } }
type SubmitChannelTask = {
    players: { Player },
    channel: string,
    time: number,
    data: unknown,
}

type Private = {
    _race: boolean,
    _syncInterval: number,
    _timeFn: () -> number,
    _remote: RemoteEvent?,
    _unreliableRemote: UnreliableRemoteEvent?,
    _registeredPlayers: { [Player]: true? },

    _latestTimeStamp: { [Player]: { [string]: number } },
    _latestData: ChannelData,
    _latestLocalData: { [Player]: ChannelData },
    _submitChannelData: { SubmitChannelTask },
    _latestReceived: { [Player]: { [string]: number } },

    _sendData: (
        self: ServerReplication,
        players: { Player },
        channelName: string,
        data: unknown
    ) -> (),
    _validateSetup: (self: ServerReplication) -> (),
    _validateChannelName: (self: ServerReplication, channelName: string) -> (),
}

export type ServerReplicationOptions = {
    race: boolean?,
    syncInterval: number?,
    timeFn: (() -> number)?,
}

local DEFAULT_RACE_OPTIONS = false
local DEFAULT_SYNC_INTERVAL = 0.5
local DEFAULT_TIME_FUNCTION = time

type ServerReplicationStatic = ServerReplication & Private & {
    new: (options: ServerReplicationOptions?) -> ServerReplication,
}

local ServerReplication: ServerReplicationStatic = {} :: any
local ServerReplicationMetatable = {
    __index = ServerReplication,
}

function ServerReplication.new(options: ServerReplicationOptions?): ServerReplication
    local options: ServerReplicationOptions = if options == nil then {} else options

    local self: Private = {
        _race = if options.race ~= nil then options.race else DEFAULT_RACE_OPTIONS,
        _syncInterval = options.syncInterval or DEFAULT_SYNC_INTERVAL,
        _timeFn = options.timeFn or DEFAULT_TIME_FUNCTION,
        _remote = nil,
        _unreliableRemote = nil,
        _registeredPlayers = {},
        _latestTimeStamp = setmetatable({}, { __mode = 'k' }) :: any,
        _latestData = {},
        _latestLocalData = setmetatable({}, { __mode = 'k' }) :: any,

        _submitChannelData = {},
        _latestReceived = {},

        -- define methods to satisfy Luau typechecking
        _sendData = nil :: any,
        _validateChannelName = nil :: any,
        _validateSetup = nil :: any,
    }

    return setmetatable(self, ServerReplicationMetatable) :: any
end

function ServerReplication:setup(parent: Instance): () -> ()
    local self: Private & ServerReplication = self :: any

    local remote = Instance.new('RemoteEvent')
    remote.Name = Constants.EventName
    remote.Parent = parent

    local unreliableRemote = Instance.new('UnreliableRemoteEvent')
    unreliableRemote.Name = Constants.FastEventName
    unreliableRemote.Parent = parent

    self._remote = remote
    self._unreliableRemote = unreliableRemote

    if self._race then
        local function submitData()
            local queue = self._submitChannelData
            self._submitChannelData = {}

            for i = #queue, 1, -1 do
                local submitInfo = queue[i]

                for _, player in submitInfo.players do
                    if self._registeredPlayers[player] then
                        local latestReceived = (self._latestReceived[player] or {} :: any)[submitInfo.channel]
                        local latestTimeStamp = (self._latestTimeStamp[player] or {} :: any)[submitInfo.channel]

                        if
                            (latestReceived or 0) < submitInfo.time and latestTimeStamp == nil
                            or latestTimeStamp == submitInfo.time
                        then
                            remote:FireClient(
                                player,
                                submitInfo.time,
                                submitInfo.channel,
                                submitInfo.data
                            )
                        end
                    end
                end
            end
        end

        local function onDataReceived(player: Player, channel: string, timeStamp: number)
            if
                type(channel) ~= 'string'
                or type(timeStamp) ~= 'number'
                or timeStamp < 0
                or not self._registeredPlayers[player]
            then
                return
            end

            local received = self._latestReceived[player]

            if received == nil then
                received = {}
                self._latestReceived[player] = received
            end

            received[channel] = timeStamp
        end

        return Teardown.fn(
            task.spawn(function()
                while true do
                    task.wait(self._syncInterval)
                    submitData()
                end
            end) :: any,
            unreliableRemote.OnServerEvent:Connect(onDataReceived) :: any
        )
    end

    return Teardown.fn()
end

function ServerReplication:registerPlayer(player: Player)
    local self: Private & ServerReplication = self :: any

    self._registeredPlayers[player] = true

    for channelName, lastValue in self._latestData do
        self:_sendData({ player }, channelName, lastValue.value)
    end

    if self._latestLocalData[player] ~= nil then
        for channelName, lastValue in self._latestLocalData[player] do
            self:_sendData({ player }, channelName, lastValue.value)
        end
    end
end

function ServerReplication:unregisterPlayer(player: Player)
    local self: Private & ServerReplication = self :: any

    self._latestTimeStamp[player] = nil
    self._registeredPlayers[player] = nil
    self._latestLocalData[player] = nil
    self._latestReceived[player] = nil
end

function ServerReplication:send(name: string, value: unknown)
    local self: Private & ServerReplication = self :: any

    if _G.DEV then
        self:_validateSetup()
        self:_validateChannelName(name)
    end

    self._latestData[name] = { value = value }

    self:_sendData(Players:GetPlayers(), name, value)
end

function ServerReplication:sendLocal(player: Player, name: string, value: unknown)
    local self: Private & ServerReplication = self :: any

    if _G.DEV then
        self:_validateSetup()
        self:_validateChannelName(name)
    end

    local localPlayerData = self._latestLocalData[player]

    if localPlayerData == nil then
        localPlayerData = {}
        self._latestLocalData[player] = localPlayerData
    end

    localPlayerData[name] = { value = value }

    self:_sendData({ player }, name, value)
end

function ServerReplication:_sendData(players: { Player }, channelName: string, data: unknown)
    local self: Private & ServerReplication = self :: any

    local unreliableRemote = self._unreliableRemote :: UnreliableRemoteEvent
    local remote = self._remote :: RemoteEvent

    local currentTime = self._timeFn()

    for _, player in players do
        local latestTimeStamps = self._latestTimeStamp[player]
        if latestTimeStamps == nil then
            latestTimeStamps = {}
            self._latestTimeStamp[player] = latestTimeStamps
        end
        latestTimeStamps[channelName] = currentTime
    end

    if self._race then
        for _, player in players do
            unreliableRemote:FireClient(player, currentTime, channelName, data)
        end

        local submitTask: SubmitChannelTask = {
            players = players,
            channel = channelName,
            time = currentTime,
            data = data,
        }
        table.insert(self._submitChannelData, submitTask)
    else
        for _, player in players do
            remote:FireClient(player, currentTime, channelName, data)
        end
    end
end

function ServerReplication:_validateSetup()
    local self: Private & ServerReplication = self :: any

    if self._remote == nil or self._unreliableRemote == nil then
        error('unable to send data before ServerReplication is setup')
    end
end

function ServerReplication:_validateChannelName(channelName: string)
    if not matchAttributeName(channelName) then
        error(
            string.format(
                'invalid channel name `%s` (must be composed of letters, numbers and '
                    .. 'underscores with a maximum of 100 characters)',
                channelName
            )
        )
    end
end

return ServerReplication
