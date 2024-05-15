local jestGlobals = require('@pkg/@jsdotlua/jest-globals')
local jest = jestGlobals.jest
local expect = jestGlobals.expect
local it = jestGlobals.it
local describe = jestGlobals.describe
local afterEach = jestGlobals.afterEach
local beforeEach = jestGlobals.beforeEach

local ChannelsBuilder = require('..')

local function mockInstance<T>(tableValue, fallbackInstance): T
    return setmetatable(tableValue, {
        __index = function(_, index)
            local result = (fallbackInstance :: any)[index]
            if type(result) == 'function' then
                return function(_self, ...)
                    return result(fallbackInstance, ...)
                end
            else
                return result
            end
        end,
        __newindex = function(_, index, value)
            fallbackInstance[index] = value
        end,
    }) :: any
end

local function mockServices()
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
        ReplicatedStorage = Instance.new('Folder') :: Instance,
        Players = mockInstance({ LocalPlayer = player }, players),
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

                local channelName = 'one'

                beforeEach(function()
                    services = mockServices()
                    serverChannels = ChannelsBuilder({}, services, true)
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
                            serverChannels.Init()
                            serverChannels.Send(channelName, value)
                            clientChannels.Init()

                            local fn, fnFunction = jest.fn()
                            teardown = bindToChannel(channelName, fnFunction)

                            task.wait()

                            expect(fn).toHaveBeenCalledTimes(1)
                            expect(fn).toHaveBeenCalledWith(value)
                        end
                    )

                    it(
                        'initializes the player, bind to channel, sends the value and the value is received',
                        function()
                            serverChannels.Init()
                            clientChannels.Init()

                            local fn, fnFunction = jest.fn()
                            teardown = bindToChannel(channelName, fnFunction)

                            serverChannels.Send(channelName, value)

                            task.wait()

                            expect(fn).toHaveBeenCalledTimes(1)
                            expect(fn).toHaveBeenCalledWith(value)
                        end
                    )

                    it(
                        'initializes the player, sends the value, bind to channel, and the value is received',
                        function()
                            serverChannels.Init()
                            clientChannels.Init()

                            serverChannels.Send(channelName, value)
                            local fn, fnFunction = jest.fn()

                            teardown = bindToChannel(channelName, fnFunction)

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
                            serverChannels.Init()
                            serverChannels.SendLocal(
                                services.Players.LocalPlayer,
                                channelName,
                                value
                            )
                            clientChannels.Init()

                            local fn, fnFunction = jest.fn()
                            teardown = bindToChannel(channelName, fnFunction)

                            task.wait()

                            expect(fn).toHaveBeenCalledTimes(1)
                            expectCall(fn, value)
                        end
                    )

                    it(
                        'initializes the player, bind to channel, sends the value and the value is received',
                        function()
                            serverChannels.Init()
                            clientChannels.Init()

                            local fn, fnFunction = jest.fn()
                            teardown = bindToChannel(channelName, fnFunction)

                            serverChannels.SendLocal(
                                services.Players.LocalPlayer,
                                channelName,
                                value
                            )

                            task.wait()

                            expect(fn).toHaveBeenCalledTimes(1)
                            expectCall(fn, value)
                        end
                    )

                    it(
                        'initializes the player, sends the value, bind to channel, and the value is received',
                        function()
                            serverChannels.Init()
                            clientChannels.Init()

                            serverChannels.SendLocal(
                                services.Players.LocalPlayer,
                                channelName,
                                value
                            )
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
