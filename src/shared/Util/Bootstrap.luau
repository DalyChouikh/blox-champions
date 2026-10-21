--!strict
-- Boots one realm (server or client): resolves the mode's config first, so an invalid config fails
-- before any module initializes, then starts the realm's modules with `Config` injectable by name.

local Config = require(script.Parent.Parent.Config)
local Loader = require(script.Parent.Loader)

export type BootOptions = {
	realm: "Server" | "Client",
	mode: Config.Mode,
	modules: { Loader.LoadableModule },
	log: ((message: string) -> ())?,
}

local Bootstrap = {}

function Bootstrap.run(options: BootOptions): (Config.GameConfig, { [string]: Loader.LoadableModule })
	local config = Config.forMode(options.mode)
	local registry = Loader.start(options.modules, { Config = config })
	local log: (message: string) -> () = options.log or print
	log(`[BloxChampions] {options.realm} ready: mode={options.mode.id}, modules={#options.modules}`)
	return config, registry
end

return Bootstrap
