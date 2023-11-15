local function isArray(value: any): boolean
    if next(value) == nil then
        -- an empty table is an empty array
        return true
    end

    local length = #value

    if length == 0 then
        return false
    end

    local expectIndex = 0

    for key in value do
        expectIndex += 1
        if type(key) ~= 'number' or key ~= expectIndex then
            return false
        end
    end

    return length == expectIndex
end

return isArray
