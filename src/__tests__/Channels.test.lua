local jestGlobals = require('@pkg/@jsdotlua/jest-globals')
local jest = jestGlobals.jest
local expect = jestGlobals.expect
local it = jestGlobals.it
local describe = jestGlobals.describe
local afterEach = jestGlobals.afterEach
local beforeEach = jestGlobals.beforeEach

local ChannelsBuilder = require('..')
local Constants = require('../impl/Constants')
local mockInstance = require('./mockInstance')

local function mockEvent()
    local bindable = Instance.new('BindableEvent')
    return mockInstance({
        Fire = function(_self, ...)
            bindable:Fire(...)
        end,
    }, bindable.Event)
end

local function mockServices(remote, unreliableRemote)
    local playerGuiMock = Instance.new('Folder')
    playerGuiMock.Name = 'PlayerGui'
    local playerInstanceMock = Instance.new('Folder')
    local player: Player = mockInstance({
        FindFirstChildOfClass = function(_self, className: string)
            return if className == 'PlayerGui'
                then playerGuiMock
                else playerInstanceMock:FindFirstChildOfClass(className)
        end,
    }, playerInstanceMock)

    local players = Instance.new('Folder')
    playerGuiMock.Parent = playerInstanceMock
    playerInstanceMock.Parent = players
    return {
        ReplicatedStorage = mockInstance({
            WaitForChild = function(_self, name)
                if name == Constants.EventName then
                    return remote
                elseif name == Constants.FastEventName then
                    return unreliableRemote
                end
                error(`unable to find child {name}`)
            end,
        }, Instance.new('Folder')),
        Players = mockInstance({
            LocalPlayer = player,
            PlayerAdded = mockEvent(),
            PlayerRemoving = mockEvent(),
            GetPlayers = function()
                return { player }
            end,
        }, players),
    }
end

local valueCases: { [string]: any } = {
    one = 1,
    zero = 0,
    ['-808'] = -808,
    ['0.123456'] = 0.123456,
    ['true'] = true,
    ['false'] = false,
    ['empty string'] = '',
    ['abc string'] = 'abc',
    ['empty table'] = {},
    ['array with one string'] = { 'hello' },
    ['array with one number'] = { 76984152 },
    ['array with three numbers'] = { 5, 6, 2 },
    ['object with one boolean property'] = { prop = true },
    ['object with one array property'] = { prop = { true, false } },
    ['array with one object with two string property'] = { { name = 'tree', description = 'wood' } },
    ['folder instance'] = Instance.new('Folder'),
    ['part instance'] = Instance.new('Part'),
    ['parented folder instance'] = (function()
        local folder = Instance.new('Folder')
        folder.Parent = workspace
        return folder
    end)(),
    ['model with part instances'] = (function()
        local model = Instance.new('Model')
        model.Name = 'Test'
        local part = Instance.new('Part')
        part.Name = 'Root'
        part.Parent = model
        return model
    end)(),
    ['array of instances'] = {
        Instance.new('Folder') :: Instance,
        Instance.new('Part'),
        Instance.new('Configuration'),
    },
    ['object with one instance property'] = {
        folder = Instance.new('Folder'),
    },
    ['object with list properties'] = {
        list = { 76984152 },
        empty = {},
        empty2 = {},
    },
    ['array of objects with one instance property'] = {
        { prop = true, folder = Instance.new('Folder') :: Instance },
        { prop = false, folder = Instance.new('Configuration') :: Instance },
    },
}

for caseName, value in valueCases do
    for _, bindFromServer in { false, true } do
        describe(
            `sending '{caseName}' and receiving on the {if bindFromServer
                then 'server'
                else 'client'}`,
            function()
                local teardown: () -> ()? = nil
                local services
                local serverChannels
                local clientChannels
                local flushSignal
                local remoteMock
                local unreliableRemoteMock

                local channelName = 'one'

                beforeEach(function()
                    flushSignal = mockEvent()
                    local newRemoteMock = {
                        FireClient = jest.fn(function(self, _player, ...)
                            self.OnClientEvent:Fire(...)
                        end),
                        OnClientEvent = mockEvent(),
                    }
                    local newUnreliableRemoteMock = {
                        FireClient = jest.fn(function(self, ...)
                            self.OnClientEvent:Fire(...)
                        end),
                        OnClientEvent = mockEvent(),
                    }
                    unreliableRemoteMock = newUnreliableRemoteMock
                    remoteMock = newRemoteMock
                    services = mockServices(remoteMock, unreliableRemoteMock)
                    serverChannels = ChannelsBuilder({}, services, true)
                    serverChannels.configure({
                        flushSignal = flushSignal,
                        remote = remoteMock,
                    })
                    clientChannels = ChannelsBuilder({}, services, false)
                end)

                afterEach(function()
                    if teardown then
                        teardown()
                        teardown = nil
                    end
                end)

                describe('using Send', function()
                    local function bindToChannel(channelName, fn)
                        return (if bindFromServer then serverChannels.Bind else clientChannels.Bind)(
                            channelName,
                            fn
                        )
                    end

                    it(
                        'sends the value, initializes the player, bind to channel and the value is received',
                        function()
                            serverChannels.Start()
                            serverChannels.Send(channelName, value)
                            clientChannels.Start()

                            local fn, fnFunction = jest.fn()
                            teardown = bindToChannel(channelName, fnFunction)

                            flushSignal:Fire(0.02)
                            task.wait()

                            expect(fn).toHaveBeenCalledTimes(1)
                            expect(fn).toHaveBeenCalledWith(value)
                        end
                    )

                    it(
                        'initializes the player, bind to channel, sends the value and the value is received',
                        function()
                            serverChannels.Start()
                            clientChannels.Start()

                            local fn, fnFunction = jest.fn()
                            teardown = bindToChannel(channelName, fnFunction)

                            serverChannels.Send(channelName, value)

                            flushSignal:Fire(0.02)
                            task.wait()

                            expect(fn).toHaveBeenCalledTimes(1)
                            expect(fn).toHaveBeenCalledWith(value)
                        end
                    )

                    it(
                        'initializes the player, sends the value, bind to channel, and the value is received',
                        function()
                            serverChannels.Start()
                            clientChannels.Start()

                            serverChannels.Send(channelName, value)
                            local fn, fnFunction = jest.fn()

                            teardown = bindToChannel(channelName, fnFunction)

                            flushSignal:Fire(0.02)
                            task.wait()

                            expect(fn).toHaveBeenCalledTimes(1)
                            expect(fn).toHaveBeenCalledWith(value)
                        end
                    )
                end)

                describe('using SendLocal', function()
                    local function bindToChannel(channelName, fn)
                        return (if bindFromServer
                            then serverChannels.BindPlayer
                            else clientChannels.Bind :: any)(
                            channelName,
                            fn
                        )
                    end

                    local function expectCall(fn, value)
                        if bindFromServer then
                            expect(fn).toHaveBeenCalledWith(services.Players.LocalPlayer, value)
                        else
                            expect(fn).toHaveBeenCalledWith(value)
                        end
                    end

                    it(
                        'sends the value, initializes the player, bind to channel and the value is received',
                        function()
                            serverChannels.Start()
                            serverChannels.SendLocal(
                                services.Players.LocalPlayer,
                                channelName,
                                value
                            )
                            clientChannels.Start()

                            local fn, fnFunction = jest.fn()
                            teardown = bindToChannel(channelName, fnFunction)

                            flushSignal:Fire(0.02)
                            task.wait()

                            expect(fn).toHaveBeenCalledTimes(1)
                            expectCall(fn, value)
                        end
                    )

                    it(
                        'initializes the player, bind to channel, sends the value and the value is received',
                        function()
                            serverChannels.Start()
                            clientChannels.Start()

                            local fn, fnFunction = jest.fn()
                            teardown = bindToChannel(channelName, fnFunction)

                            serverChannels.SendLocal(
                                services.Players.LocalPlayer,
                                channelName,
                                value
                            )
                            flushSignal:Fire(0.02)

                            task.wait()

                            expect(fn).toHaveBeenCalledTimes(1)
                            expectCall(fn, value)
                        end
                    )

                    it(
                        'initializes the player, sends the value, bind to channel, and the value is received',
                        function()
                            serverChannels.Start()
                            clientChannels.Start()

                            serverChannels.SendLocal(
                                services.Players.LocalPlayer,
                                channelName,
                                value
                            )
                            flushSignal:Fire(0.02)

                            local fn, fnFunction = jest.fn()

                            teardown = bindToChannel(channelName, fnFunction)

                            task.wait()

                            expect(fn).toHaveBeenCalledTimes(1)
                            expectCall(fn, value)
                        end
                    )
                end)
            end
        )
    end
end
