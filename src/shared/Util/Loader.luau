--!strict
-- Starts modules in declared order with explicit dependencies: every `init` runs first, then every `start`.
-- The module list is fully validated before any `init` runs, so a bad list never half-starts the game.

export type LoadableModule = {
	name: string,
	dependencies: { string }?,
	init: ((self: any, deps: { [string]: any }) -> ())?,
	start: ((self: any) -> ())?,
}

local Loader = {}

local function validate(modules: { LoadableModule }, provided: { [string]: any })
	local positions: { [string]: number } = {}
	for index, module in modules do
		if positions[module.name] ~= nil then
			error(`Loader: duplicate module name "{module.name}"`, 0)
		end
		if provided[module.name] ~= nil then
			error(`Loader: module name "{module.name}" collides with a provided value`, 0)
		end
		positions[module.name] = index
	end

	for index, module in modules do
		local dependencies: { string } = module.dependencies or {}
		for _, dependency in dependencies do
			if provided[dependency] == nil then
				local position = positions[dependency]
				if position == nil then
					error(`Loader: module "{module.name}" depends on unknown module "{dependency}"`, 0)
				elseif position >= index then
					error(`Loader: module "{module.name}" depends on "{dependency}", which is declared after it`, 0)
				end
			end
		end
	end
end

local function runPhase(module: LoadableModule, phase: string, fn: (...any) -> ...any, ...: any)
	local ok, message = pcall(fn, ...)
	if not ok then
		error(`Loader: module "{module.name}" failed in {phase}: {message}`, 0)
	end
end

function Loader.start(modules: { LoadableModule }, provided: { [string]: any }?): { [string]: LoadableModule }
	local providedValues = provided or {}
	validate(modules, providedValues)

	local registry: { [string]: LoadableModule } = {}
	for _, module in modules do
		registry[module.name] = module
	end

	for _, module in modules do
		local init = module.init
		if init ~= nil then
			local deps: { [string]: any } = {}
			local dependencies: { string } = module.dependencies or {}
			for _, dependency in dependencies do
				local value = providedValues[dependency]
				deps[dependency] = if value ~= nil then value else registry[dependency]
			end
			runPhase(module, "init", init, module, deps)
		end
	end

	for _, module in modules do
		local start = module.start
		if start ~= nil then
			runPhase(module, "start", start, module)
		end
	end

	return registry
end

return Loader
