local jestGlobals = require('@pkg/@jsdotlua/jest-globals')

local jest = jestGlobals.jest

local function mockInstance<T>(tableValue, fallbackInstance): T
    return setmetatable(tableValue, {
        __index = function(_, index)
            local result = (fallbackInstance :: any)[index]

            if type(result) == 'function' then
                local mockInstance = jest.fn(function(_self, ...)
                    return result(fallbackInstance, ...)
                end)
                rawset(tableValue, index, mockInstance)

                return mockInstance
            else
                return result
            end
        end,
        __newindex = function(_, index, value)
            fallbackInstance[index] = value
        end,
    }) :: any
end

return mockInstance
