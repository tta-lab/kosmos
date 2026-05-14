local wezterm = require("wezterm")

local config = {
	default_prog = { "/run/current-system/sw/bin/fish", "-l" },
	term = "wezterm",
	automatically_reload_config = true,
}

return config
