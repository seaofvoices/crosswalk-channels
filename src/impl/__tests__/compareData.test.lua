local jestGlobals = require('@pkg/@jsdotlua/jest-globals')

local expect = jestGlobals.expect
local it = jestGlobals.it

local compareData = require('../compareData')

it('returns true for equal numbers', function()
    expect(compareData(42, 42)).toEqual(true)
end)

it('returns true for equal strings', function()
    expect(compareData('hello', 'hello')).toEqual(true)
end)

it('returns true for equal Vector3 values', function()
    expect(compareData(Vector3.new(1, 2, 3), Vector3.new(1, 2, 3))).toEqual(true)
end)

it('returns true for equal Color3 values', function()
    expect(compareData(Color3.new(1, 0, 0), Color3.new(1, 0, 0))).toEqual(true)
end)

it('returns true for equal Enum values', function()
    expect(compareData(Enum.KeyCode.A, Enum.KeyCode.A)).toEqual(true)
end)

it('returns true for two nil values', function()
    expect(compareData(nil, nil)).toEqual(true)
end)

it('returns false for unequal numbers', function()
    expect(compareData(42, 43)).toEqual(false)
end)

it('returns false for unequal strings', function()
    expect(compareData('hello', 'world')).toEqual(false)
end)

it('returns false for unequal Vector3 values', function()
    expect(compareData(Vector3.new(1, 2, 3), Vector3.new(4, 5, 6))).toEqual(false)
end)

it('returns false for unequal Color3 values', function()
    expect(compareData(Color3.new(1, 0, 0), Color3.new(0, 1, 0))).toEqual(false)
end)

it('returns false for unequal Enum values', function()
    expect(compareData(Enum.KeyCode.A, Enum.KeyCode.B)).toEqual(false)
end)

it('returns false for a number and a string', function()
    expect(compareData(42, '42')).toEqual(false)
end)

it('returns false for Vector3 and Color3', function()
    expect(compareData(Vector3.new(1, 2, 3), Color3.new(1, 0, 0))).toEqual(false)
end)

it('returns false for Enum and number', function()
    expect(compareData(Enum.KeyCode.A, 1)).toEqual(false)
end)

it('returns false for tables', function()
    expect(compareData({ 1, 2, 3 }, { 1, 2, 3 })).toEqual(false)
end)

it('returns false for functions', function()
    expect(compareData(function() end, function() end)).toEqual(false)
end)

it('returns false for nil and a number', function()
    expect(compareData(nil, 42)).toEqual(false)
end)

it('returns false for a number and nil', function()
    expect(compareData(42, nil)).toEqual(false)
end)

it('returns false for mismatched comparable types', function()
    expect(compareData(42, '42')).toEqual(false)
end)

it('returns false for Color3 and Vector3', function()
    expect(compareData(Color3.new(1, 0, 0), Vector3.new(1, 0, 0))).toEqual(false)
end)
