local jestGlobals = require('@pkg/@jsdotlua/jest-globals')
local expect = jestGlobals.expect
local it = jestGlobals.it

local clearAttributes = require('../clearAttributes')

local function anyInstance(): Instance
    return Instance.new('Folder')
end

it('clears no attributes', function()
    local instance = anyInstance()
    clearAttributes(instance)
    expect(instance:GetAttributes()).toEqual({})
end)

it('clears one attribute', function()
    local instance = anyInstance()
    instance:SetAttribute('name', true)
    expect(instance:GetAttributes()).toEqual({ name = true })
    clearAttributes(instance)
    expect(instance:GetAttributes()).toEqual({})
end)

it('clears all attributes', function()
    local instance = anyInstance()
    instance:SetAttribute('name', true)
    instance:SetAttribute('name2', false)
    instance:SetAttribute('name3', 10)
    clearAttributes(instance)
    expect(instance:GetAttributes()).toEqual({})
end)

return nil
