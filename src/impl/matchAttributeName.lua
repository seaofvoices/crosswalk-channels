local function matchAttributeName(value: string): boolean
    return #value <= 100
        and string.sub(value, 1, 3) ~= 'RBX'
        and string.match(value, '^[%w_]+$') ~= nil
end

return matchAttributeName
