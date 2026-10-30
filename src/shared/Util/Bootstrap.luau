--!strict
-- Boots one realm (server or client): resolves the mode's config first, so an invalid config fails before any module
-- initializes, gives the world the config's gravity, then starts the realm's modules with `Config` injectable by name.

local Config = require(script.Parent.Parent.Config)
local Loader = require(script.Parent.Loader)

export type BootOptions = {
	realm: "Server" | "Client",
	mode: Config.Mode,
	modules: { Loader.LoadableModule },
	-- Where Roblox's own physics reads its gravity: the Workspace, or a stand-in in tests.
	world: { Gravity: number }?,
	log: ((message: string) -> ())?,
}

local Bootstrap = {}

function Bootstrap.run(options: BootOptions): (Config.GameConfig, { [string]: Loader.LoadableModule })
	local config = Config.forMode(options.mode)
	-- Roblox's own physics (the ball's flight, the characters) pulls as hard as the skating, poses and rules read
	-- (#279). Both realms set it, so a client never runs a frame at another gravity before the server's arrives.
	local world: { Gravity: number } = options.world or workspace :: any
	world.Gravity = config.World.gravity
	local registry = Loader.start(options.modules, { Config = config })
	local log: (message: string) -> () = options.log or print
	log(`[BloxChampions] {options.realm} ready: mode={options.mode.id}, modules={#options.modules}`)
	return config, registry
end

return Bootstrap
