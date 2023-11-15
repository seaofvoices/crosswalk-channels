local function createFolder(name: string, parent: Instance?): Folder
    local container = Instance.new('Folder')
    container.Name = name
    container.Parent = parent
    return container
end

return createFolder
