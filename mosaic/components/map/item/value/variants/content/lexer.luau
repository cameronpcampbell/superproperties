--!strict

local Packages = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.packages
local Lexuau = require(Packages.lexuau)

type State = {}

local function NewState(): State
	return {}
end

local UriBodyLexer = Lexuau.new
	<< State
	>> {
		init_state = NewState,

		patterns = {
			assetId = {
				pattern = "[\\d]+",
				priority = 4,
			},
			uriBody = {
				pattern = "[^\\s]+",
				priority = 1,
			},
		},
	}

local AfterSchemeLexer = Lexuau.new
	<< State
	>> {
		init_state = NewState,

		patterns = {
			separator = {
				pattern = "://",
				callback = function(value: string, _state: State): (string, Lexuau.Lexer<State>)
					return value, UriBodyLexer
				end,
			},
		},
	}

return Lexuau.new
	<< State
	>> {
		init_state = NewState,

		patterns = {
			assetId = "[\\d]+",
			scheme = {
				pattern = "[A-Za-z][A-Za-z0-9+.-]*",
				callback = function(value: string, _state: State): (string, Lexuau.Lexer<State>)
					return value, AfterSchemeLexer
				end,
			},
		},
	}
