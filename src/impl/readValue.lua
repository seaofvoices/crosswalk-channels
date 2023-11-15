local Constants = require('./Constants')

local readValue

local function readInstance(instance: Instance): any
    if instance:IsA('ValueBase') then
        return (instance :: any).Value
    elseif instance:IsA('Folder') then
        if instance:HasTag(Constants.ListTag) then
            local length = instance:GetAttribute(Constants.ListLengthAttribute) or 0
            local list = table.create(length, 0)

            for i = 1, length do
                local elementName = tostring(i)
                list[i] = readValue(instance, elementName)
            end

            return list
        elseif instance:HasTag(Constants.ValueAttribute) then
            return instance:GetAttribute(Constants.ValueAttribute)
        else
            local object = instance:GetAttributes()

            for _, child in instance:GetChildren() do
                object[child.Name] = readInstance(child)
            end
            return object
        end
    else
        if _G.DEV then
            error(string.format('unsupported instance of class `%s`', instance.ClassName))
        end
        return
    end
end

function readValue(container: Instance, name: string): any
    local attribute = container:GetAttribute(name)
    if attribute ~= nil then
        return attribute
    end

    local child = container:FindFirstChild(name)
    if child == nil then
        return nil
    else
        return readInstance(child)
    end
end

return readValue
