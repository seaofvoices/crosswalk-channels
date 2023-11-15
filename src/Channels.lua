return function(_SharedModules, Services, isServer)
    local module = {}

    if isServer then
        local ServerReplication = require('./impl/ServerReplication')

        local serverReplication = ServerReplication.new()

        function module.Init()
            serverReplication:setup(Services.ReplicatedStorage)
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
        end

        function module.Send(name: string, value: unknown)
            if _G.DEV then
                assert(
                    type(name) == 'string',
                    string.format('expected argument #1 to be a string, received %s', type(name))
                )
            end

            serverReplication:send(name, value)
        end
    else
        local ClientReplication = require('./impl/ClientReplication')

        local clientReplication = ClientReplication.new()

        function module.Init()
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
    end

    return module
end
