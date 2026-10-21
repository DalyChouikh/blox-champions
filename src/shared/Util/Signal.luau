--!strict
-- Synchronous signal. Handlers run in connection order; a handler that errors is reported
-- and never stops the remaining handlers.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

type ConnectionRecord = {
	Connected: boolean,
	Disconnect: (self: any) -> (),
	_connections: { ConnectionRecord },
	_handler: (...any) -> ...any,
	_once: boolean,
}

local Signal = {}

local function disconnect(connection: ConnectionRecord)
	if not connection.Connected then
		return
	end
	connection.Connected = false
	local index = table.find(connection._connections, connection)
	if index ~= nil then
		table.remove(connection._connections, index)
	end
end

local function connect(signal: any, handler: (...any) -> (), once: boolean): Connection
	local connection: ConnectionRecord = {
		Connected = true,
		Disconnect = disconnect,
		_connections = signal._connections,
		_handler = handler,
		_once = once,
	}
	table.insert(signal._connections, connection)
	return connection :: any
end

local methods = {}

function methods.Connect(self: any, handler: (...any) -> ()): Connection
	return connect(self, handler, false)
end

function methods.Once(self: any, handler: (...any) -> ()): Connection
	return connect(self, handler, true)
end

function methods.Fire(self: any, ...: any)
	-- Iterate a snapshot so handlers connected during this fire wait for the next one.
	local snapshot: { ConnectionRecord } = table.clone(self._connections)
	for _, connection in snapshot do
		if connection.Connected then
			if connection._once then
				disconnect(connection)
			end
			local ok, message = xpcall(connection._handler, debug.traceback, ...)
			if not ok then
				self._onHandlerError(message)
			end
		end
	end
end

function methods.DisconnectAll(self: any)
	for _, connection in self._connections do
		connection.Connected = false
	end
	table.clear(self._connections)
end

function Signal.new<T...>(onHandlerError: ((message: string) -> ())?): Signal<T...>
	local signal = setmetatable({
		_connections = {},
		_onHandlerError = onHandlerError or warn,
	}, { __index = methods })
	return signal :: any
end

return Signal
