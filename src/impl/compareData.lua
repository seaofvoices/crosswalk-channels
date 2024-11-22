local COMPARABLE_TYPES = {
    ['nil'] = true,
    number = true,
    string = true,
    CFrame = true,
    Vector2 = true,
    Vector2int16 = true,
    Vector3 = true,
    Vector3int16 = true,
    UDim = true,
    UDim2 = true,
    Color3 = true,
    Enum = true,
    EnumItem = true,
    Rect = true,
    Ray = true,
}

local function compareData(value1: unknown, value2: unknown): boolean
    local valueType = typeof(value1)
    if valueType ~= typeof(value2) then
        return false
    end

    return COMPARABLE_TYPES[valueType] == true and value1 == value2
end

return compareData
