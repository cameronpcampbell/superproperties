--!strict
--!nolint LocalShadow

local Package =
    script.Parent.Parent.Parent.Parent[".pesde"]["elttob_fusion@0.3.0"].fusion
local Types = require(Package.Types)
local External = require(Package.External)
local Computed = require(Package.State.Computed)
local castToState = require(Package.State.castToState)

type Transformer = (scope: Types.Scope<unknown>, child: unknown) -> Types.Child?

local function ChildrenTransform(
	scope: Types.Scope<unknown>,
	transformer: Transformer,
	children: unknown
): Types.Child?
	local processChild: (child: unknown) -> Types.Child?
	local processTransformedChild: (child: unknown, originalType: string) -> Types.Child?

	local function processState(
		child: Types.StateObject<unknown>,
		processValue: (value: unknown) -> Types.Child?
	): Types.Child
		return Computed(scope, function(use): Types.Child?
			local value = use(child)

			if value == nil then
				return nil
			end

			return processValue(value)
		end) :: any
	end

	processTransformedChild = function(
		child: unknown,
		originalType: string
	): Types.Child?
		local childType = typeof(child)

		if child == nil then
			External.logWarn("unrecognisedChildType", originalType)
			return nil

		elseif childType == "Instance" then
			return child :: Instance

		elseif castToState(child) then
			return processState(
				child :: Types.StateObject<unknown>,
				function(value)
					return processTransformedChild(value, typeof(value))
				end
			)

		elseif childType == "table" then
			local transformedChildren: {[unknown]: Types.Child} = {}

			for key, subChild in pairs(child :: {[unknown]: unknown}) do
				local transformedChild = processTransformedChild(subChild, typeof(subChild))

				if transformedChild ~= nil then
					transformedChildren[key] = transformedChild
				end
			end

			return transformedChildren
		end

		External.logWarn("unrecognisedChildType", originalType)
		return nil
	end

	processChild = function(child: unknown): Types.Child?
		local childType = typeof(child)

		if child == nil then
			return nil

		elseif childType == "Instance" then
			return child :: Instance

		elseif castToState(child) then
			return processState(
				child :: Types.StateObject<unknown>,
				processChild
			)

		elseif childType == "table" then
			local transformedChildren: {[unknown]: Types.Child} = {}

			for key, subChild in pairs(child :: {[unknown]: unknown}) do
				local transformedChild = processChild(subChild)

				if transformedChild ~= nil then
					transformedChildren[key] = transformedChild
				end
			end

			return transformedChildren
		end

		return processTransformedChild(transformer(scope, child), childType)
	end

	return processChild(children)
end

return ChildrenTransform
