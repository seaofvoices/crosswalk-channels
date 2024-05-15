local jestGlobals = require('@pkg/@jsdotlua/jest-globals')
local expect = jestGlobals.expect
local it = jestGlobals.it

local matchAttributeName = require('../matchAttributeName')

local falseCases = {
    '',
    'spaced name',
    string.rep('0', 101),
    -- special case where atttributes starting with `RBX` are reserved to Roblox
    'RBX',
    'RBX_property',
    'RBX10',
}

local trueCases = {
    'a',
    'abc',
    '__',
    '_abc',
    '100',
    'hello1',
    '10items',
}

for _, case in falseCases do
    it(string.format('is false for `%s`', case), function()
        expect(matchAttributeName(case)).toBe(false)
    end)
end

for _, case in trueCases do
    it(string.format('is true for `%s`', case), function()
        expect(matchAttributeName(case)).toBe(true)
    end)
end

return nil
