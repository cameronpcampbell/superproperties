--!strict

local CapabilityItems = Enum.SecurityCapability:GetEnumItems()
local AllCapabilities =
	SecurityCapabilities.new(table.unpack(CapabilityItems))

local PluginCapabilities: SecurityCapabilities? = nil

local function Capture()
	if PluginCapabilities ~= nil then
		return
	end

	PluginCapabilities = SecurityCapabilities.fromCurrent():Add(
		Enum.SecurityCapability.Basic,
		Enum.SecurityCapability.Plugin,
		Enum.SecurityCapability.PluginOrOpenCloud
	)
end

local function GetPlugin(): SecurityCapabilities
	local capabilities = PluginCapabilities
	assert(
		capabilities,
		"Reflection security must be captured during plugin startup."
	)
	return capabilities
end

local function ContainsAll(
	available: SecurityCapabilities,
	required: SecurityCapabilities
): boolean
	for _, capability in CapabilityItems do
		if required:Contains(capability)
			and not available:Contains(capability)
		then
			return false
		end
	end

	return true
end

local function DescribeMissing(
	required: SecurityCapabilities
): string
	local available = GetPlugin()
	local missing = {} :: { string }

	for _, capability in CapabilityItems do
		if required:Contains(capability)
			and not available:Contains(capability)
		then
			table.insert(missing, capability.Name)
		end
	end

	return
		if #missing > 0 then table.concat(missing, ", ")
		else "Unavailable"
end

return {
	All = AllCapabilities,
	Capture = Capture,
	GetPlugin = GetPlugin,
	ContainsAll = ContainsAll,
	DescribeMissing = DescribeMissing,
}
