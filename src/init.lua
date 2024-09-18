return function(_SharedModules, Services, isServer)
    local module = {}

    type Configuration = {
        race: boolean?,
        syncInterval: number?,
        timeFn: (() -> number)?,
    }

    if isServer then
        local ServerReplication = require('./impl/ServerReplication')
        local Signal = require('@pkg/luau-signal')

        type Signal<T...> = Signal.Signal<T...>

        local serverReplication = ServerReplication.new()

        local globalSignals: { [string]: Signal<any> } = {}
        local localSignals: { [string]: Signal<Player, any> } = {}

        local lastGlobalValues: { [string]: { value: any } } = {}
        local lastLocalValues: { [Player]: { [string]: { value: any } } } = {}
        setmetatable(lastLocalValues :: any, { __mode = 'k' })

        function module.configure(config: Configuration)
            serverReplication:setOptions(config)
        end

        function module.Start()
            serverReplication:setup(Services.ReplicatedStorage)

            local players: Players = Services.Players

            players.PlayerAdded:Connect(function(player: Player)
                serverReplication:registerPlayer(player)
            end)

            players.PlayerRemoving:Connect(function(player: Player)
                serverReplication:unregisterPlayer(player)
            end)
        end

        function module.SendLocal(player: Player, name: string, value: unknown)
            if _G.DEV then
                assert(
                    typeof(player) == 'Instance' and player.ClassName == 'Player',
                    'expected argument #1 to be a Player'
                )
                assert(
                    type(name) == 'string',
                    string.format('expected argument #2 to be a string, received %s', type(name))
                )
            end

            serverReplication:sendLocal(player, name, value)
            local playerLastValues = lastLocalValues[player]
            if playerLastValues == nil then
                playerLastValues = { [name] = { value = value } }
                lastLocalValues[player] = playerLastValues
            else
                playerLastValues[name] = { value = value }
            end

            local signal = localSignals[name]
            if signal then
                signal:fire(player, value)
            end
        end
        module.sendLocal = module.SendLocal

        function module.BindPlayer<T>(name: string, fn: (Player, T) -> ()): () -> ()
            if _G.DEV then
                assert(
                    type(name) == 'string',
                    string.format('expected argument #1 to be a string, received %s', type(name))
                )
                assert(type(fn) == 'function', 'expected argument #2 to be a function')
            end
            local signal = localSignals[name]
            if signal == nil then
                signal = Signal.new()
                localSignals[name] = signal
            end
            for player, playerLastValues in lastLocalValues do
                if playerLastValues[name] ~= nil then
                    task.spawn(fn, player, playerLastValues[name].value)
                end
            end
            return signal:connect(fn):disconnectFn()
        end
        module.bindPlayer = module.BindPlayer

        function module.Send(name: string, value: unknown)
            if _G.DEV then
                assert(
                    type(name) == 'string',
                    string.format('expected argument #1 to be a string, received %s', type(name))
                )
            end

            serverReplication:send(name, value)
            lastGlobalValues[name] = { value = value }
            local signal = globalSignals[name]
            if signal then
                signal:fire(value)
            end
        end
        module.send = module.Send

        function module.Bind<T>(name: string, fn: (T) -> ()): () -> ()
            if _G.DEV then
                assert(
                    type(name) == 'string',
                    string.format('expected argument #1 to be a string, received %s', type(name))
                )
                assert(type(fn) == 'function', 'expected argument #2 to be a function')
            end
            local signal = globalSignals[name]
            if signal == nil then
                signal = Signal.new()
                globalSignals[name] = signal
            end
            if lastGlobalValues[name] ~= nil then
                task.spawn(fn, lastGlobalValues[name].value)
            end
            return signal:connect(fn):disconnectFn()
        end
        module.bind = module.Bind
    else
        local ClientReplication = require('./impl/ClientReplication')

        local clientReplication = ClientReplication.new()

        function module.configure(config: Configuration)
            clientReplication:setOptions(config)
        end

        function module.Start()
            task.spawn(function()
                clientReplication:setup(Services.ReplicatedStorage, Services.Players.LocalPlayer)
            end)
        end

        function module.Bind<T>(name: string, fn: (T) -> ()): () -> ()
            if _G.DEV then
                assert(
                    type(name) == 'string',
                    string.format('expected argument #1 to be a string, received %s', type(name))
                )
                assert(type(fn) == 'function', 'expected argument #2 to be a function')
            end
            return clientReplication:bind(name, fn)
        end
        module.bind = module.Bind
    end

    return module
end
