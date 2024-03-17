local Constants = require('./Constants')
local clearAttributes = require('./clearAttributes')
local createFolder = require('./createFolder')
local isArray = require('./isArray')
local isEmpty = require('./isEmpty')
local matchAttributeName = require('./matchAttributeName')

local function getType(value: unknown): string
    local valueType = type(value)

    if valueType == 'vector' or valueType == 'userdata' then
        return typeof(value)
    else
        return valueType
    end
end

local function writeFolder(name: string, parent: Instance)
    local child = parent:FindFirstChild(name)
    if child and child.ClassName ~= 'Folder' then
        child:Destroy()
        child = nil
    end
    if child then
        return child
    else
        return createFolder(name, parent)
    end
end

local function writeValue(folder: Folder, name: string, value: unknown)
    local valueType = getType(value)

    if
        valueType == 'string'
        or valueType == 'boolean'
        or valueType == 'number'
        or valueType == 'Color3'
        or valueType == 'Vector2'
        or valueType == 'Vector3'
        or valueType == 'CFrame'
        or valueType == 'UDim'
        or valueType == 'UDim2'
    then
        local currentChild = folder:FindFirstChild(name)

        if matchAttributeName(name) then
            folder:SetAttribute(name, value)
            if currentChild then
                currentChild:Destroy()
            end
        else
            local attributeHolder: Instance
            if currentChild == nil then
                attributeHolder = createFolder(name, folder)
            elseif currentChild.ClassName == 'Folder' then
                attributeHolder = currentChild
            else
                currentChild:Destroy()
                attributeHolder = createFolder(name, folder)
            end
            attributeHolder:AddTag(Constants.ValueAttribute)
            attributeHolder:SetAttribute(Constants.ValueAttribute, value)
        end
    elseif valueType == 'Instance' then
        folder:SetAttribute(name, nil)
        local currentChild = folder:FindFirstChild(name)

        if currentChild == nil then
            local objectValue = Instance.new('ObjectValue')
            objectValue.Name = name
            objectValue.Value = value :: Instance
            objectValue.Parent = folder
        elseif currentChild.ClassName == 'ObjectValue' then
            (currentChild :: ObjectValue).Value = value :: Instance
        else
            currentChild:Destroy()
            local objectValue = Instance.new('ObjectValue')
            objectValue.Name = name
            objectValue.Value = value :: Instance
            objectValue.Parent = folder
        end
    elseif valueType == 'table' then
        folder:SetAttribute(name, nil)
        local valueFolder = writeFolder(name, folder)
        if isEmpty(value :: any) then
            clearAttributes(valueFolder)
            valueFolder:ClearAllChildren()
            valueFolder:RemoveTag(Constants.ListTag)
            valueFolder:SetAttribute(Constants.ListLengthAttribute, nil)
            valueFolder:RemoveTag(Constants.ValueAttribute)
            valueFolder:SetAttribute(Constants.ValueAttribute, nil)
        elseif isArray(value :: any) then
            local array: { any } = value :: any

            valueFolder:RemoveTag(Constants.ValueAttribute)
            valueFolder:SetAttribute(Constants.ValueAttribute, nil)

            local previousLength = valueFolder:GetAttribute(Constants.ListLengthAttribute)

            valueFolder:AddTag(Constants.ListTag)

            local currentLength = #array

            if previousLength and previousLength > currentLength then
                for i = currentLength + 1, previousLength do
                    local previousElementName = tostring(i)
                    local previousElement = valueFolder:FindFirstChild(previousElementName)

                    if previousElement then
                        previousElement:Destroy()
                    else
                        valueFolder:SetAttribute(previousElementName, nil)
                    end
                end
            end

            valueFolder:SetAttribute(Constants.ListLengthAttribute, currentLength)

            for index, element in array do
                local elementName = tostring(index)

                writeValue(valueFolder :: Folder, elementName, element)
            end
        else
            valueFolder:RemoveTag(Constants.ValueAttribute)
            valueFolder:SetAttribute(Constants.ValueAttribute, nil)
            valueFolder:RemoveTag(Constants.ListTag)
            valueFolder:SetAttribute(Constants.ListLengthAttribute, nil)

            local dictionary = value :: { [any]: unknown }

            for _, child in valueFolder:GetChildren() do
                local key = child.Name
                if dictionary[key] == nil then
                    child:Destroy()
                end
            end
            for attribute in valueFolder:GetAttributes() do
                if dictionary[attribute] == nil then
                    valueFolder:SetAttribute(attribute, nil)
                end
            end

            for key, innerValue in dictionary do
                if type(key) == 'string' then
                    writeValue(valueFolder :: Folder, key, innerValue)
                else
                    error(string.format('unsupported type for table key `%s`', valueType))
                end
            end
        end
    elseif value == nil then
        folder:SetAttribute(name, nil)
        local currentChild = folder:FindFirstChild(name)
        if currentChild then
            currentChild:Destroy()
        end
    else
        error(string.format('unsupported value of type `%s`', valueType))
    end
end

return writeValue
