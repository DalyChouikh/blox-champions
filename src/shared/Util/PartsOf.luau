--!strict
-- Every part of `instance`: itself when it is one, then its descendants that are parts (a model's parts, or a part an
-- art pass tagged on its own).

return function(instance: Instance): { BasePart }
	local parts: { BasePart } = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end
