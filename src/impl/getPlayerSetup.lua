local Constants = require('./Constants')
local createFolder = require('./createFolder')

local function getPlayerSetup(player: Player): { values: Folder, counters: Folder }?
    local playerGui = player:FindFirstChildOfClass('PlayerGui')

    while playerGui == nil and player.Parent ~= nil do
        task.wait()
        playerGui = player:FindFirstChildOfClass('PlayerGui')
    end

    if playerGui == nil then
        return nil
    end

    local playerGui = playerGui :: PlayerGui

    local valuesFolder = playerGui:FindFirstChild(Constants.LocalPlayerContainerName)
    if valuesFolder and not valuesFolder:IsA('Folder') then
        valuesFolder = nil
    end

    if valuesFolder == nil then
        valuesFolder = createFolder(Constants.LocalPlayerContainerName, playerGui)
    end

    local countersFolder = playerGui:FindFirstChild(Constants.CounterContainerName)
    if countersFolder and not countersFolder:IsA('Folder') then
        countersFolder = nil
    end

    if countersFolder == nil then
        countersFolder = createFolder(Constants.CounterContainerName, playerGui)
    end

    return if valuesFolder and countersFolder
        then {
            values = valuesFolder :: Folder,
            counters = countersFolder :: Folder,
        }
        else nil
end

return getPlayerSetup
