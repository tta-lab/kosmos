local wezterm = require("wezterm")

local config = {
	default_prog = { "/run/current-system/sw/bin/fish", "-l" },
	term = "wezterm",
	automatically_reload_config = true,
	set_environment_variables = {
		HOME = "/home/neil",
		USER = "neil",
		LOGNAME = "neil",
		XDG_CONFIG_HOME = "/home/neil/.config",
		XDG_DATA_HOME = "/home/neil/.local/share",
		XDG_CACHE_HOME = "/home/neil/.cache",
		TMPDIR = "/tmp",
		TMP = "/tmp",
		TEMP = "/tmp",
	},
}

return config
