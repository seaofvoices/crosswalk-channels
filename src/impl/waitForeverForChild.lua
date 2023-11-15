local function waitForeverForChild(parent: Instance, name: string): Instance
    return parent:WaitForChild(name, math.huge) :: Instance
end

return waitForeverForChild
