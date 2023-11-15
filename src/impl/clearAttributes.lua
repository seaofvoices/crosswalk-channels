local function clearAttributes(instance: Instance)
    for attribute in instance:GetAttributes() do
        instance:SetAttribute(attribute, nil)
    end
end

return clearAttributes
