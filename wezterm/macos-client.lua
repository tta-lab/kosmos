local wezterm = require("wezterm")
local mux = wezterm.mux
local act = wezterm.action

local ssh_host = os.getenv("KOSMOS_WEZTERM_SSH_HOST") or "frp-fast"
local domain_name = os.getenv("KOSMOS_WEZTERM_DOMAIN") or "kosmos-wsl"
local remote_address = os.getenv("KOSMOS_WEZTERM_REMOTE") or ssh_host
local username = os.getenv("KOSMOS_WEZTERM_USER") or "neil"

local starlight = {
	foreground = "#ffffff",
	background = "#242424",
	cursor_bg = "#ffffff",
	cursor_fg = "#242424",
	selection_bg = "#ffffff",
	selection_fg = "#242424",
	ansi = { "#242424", "#f62b5a", "#47b413", "#e3c401", "#24acd4", "#f2affd", "#13c299", "#e6e6e6" },
	brights = { "#616161", "#ff4d51", "#35d450", "#e9e836", "#5dc5f8", "#feabf2", "#24dfc4", "#ffffff" },
}

local mouse_bindings = {
	{
		event = { Down = { streak = 1, button = "Right" } },
		mods = "NONE",
		action = act({ PasteFrom = "Clipboard" }),
	},
}

local function split_once(value, sep)
	local index = string.find(value, sep, 1, true)
	if not index then
		return value, ""
	end
	return string.sub(value, 1, index - 1), string.sub(value, index + string.len(sep))
end

local function load_project_choices()
	local ok, stdout, stderr = wezterm.run_child_process({ "ssh", ssh_host, "ttal-wezterm-projects", "--choices" })
	if not ok then
		wezterm.log_error("failed to load TTAL WezTerm projects: " .. stderr)
		return {}
	end

	local ok_json, choices = pcall(wezterm.json_parse, stdout)
	if not ok_json or type(choices) ~= "table" then
		wezterm.log_error("ttal-wezterm-projects returned invalid JSON: " .. stdout)
		return {}
	end

	return choices
end

local function choose_project(window, pane)
	local choices = load_project_choices()
	if #choices == 0 then
		window:toast_notification("WezTerm", "No TTAL projects found through " .. ssh_host, nil, 4000)
		return
	end

	window:perform_action(
		act.InputSelector({
			title = "TTAL project",
			choices = choices,
			fuzzy = true,
			fuzzy_description = "Pick a project workspace",
			action = wezterm.action_callback(function(inner_window, inner_pane, id)
				if not id then
					return
				end

				local workspace, path = split_once(id, "\t")
				if workspace == "" or path == "" then
					wezterm.log_error("invalid TTAL project choice: " .. id)
					return
				end

				inner_window:perform_action(
					act.SwitchToWorkspace({
						name = workspace,
						spawn = {
							label = workspace,
							cwd = path,
							domain = { DomainName = domain_name },
						},
					}),
					inner_pane
				)
			end),
		}),
		pane
	)
end

local config = {
	mouse_bindings = mouse_bindings,
	font_size = 18,

	send_composed_key_when_left_alt_is_pressed = false,
	font = wezterm.font("FiraCode Nerd Font Mono"),
	font_rules = {
		{
			intensity = "Bold",
			font = wezterm.font("FiraCode Nerd Font Mono", { weight = "Bold" }),
		},
		{
			intensity = "Bold",
			italic = true,
			font = wezterm.font("FiraCode Nerd Font Mono", { weight = "Bold", italic = true }),
		},
	},
	colors = starlight,
	default_prog = { "/opt/homebrew/bin/fish", "-l" },

	ssh_domains = {
		{
			name = domain_name,
			remote_address = remote_address,
			username = username,
			multiplexing = "WezTerm",
			remote_wezterm_path = "/run/current-system/sw/bin/wezterm",
		},
	},

	use_fancy_tab_bar = true,
	hide_tab_bar_if_only_one_tab = true,
	show_new_tab_button_in_tab_bar = false,

	enable_scroll_bar = true,
	scrollback_lines = 10000,

	window_decorations = "RESIZE",
	adjust_window_size_when_changing_font_size = false,

	window_padding = {
		left = 20,
		right = 20,
		top = 20,
		bottom = 5,
	},

	native_macos_fullscreen_mode = true,

	keys = {
		{
			key = "m",
			mods = "SHIFT|CTRL",
			action = act.ToggleFullScreen,
		},
		{
			key = "P",
			mods = "SHIFT|CTRL",
			action = wezterm.action_callback(choose_project),
		},
		{
			key = "9",
			mods = "ALT",
			action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }),
		},
	},
}

wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

return config
