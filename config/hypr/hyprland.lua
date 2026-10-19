-- Strata defaults are owned by the RPM. Personal Lua below the requires
-- always wins and is never replaced during package upgrades.
package.path = "/usr/share/strata/?.lua;/usr/share/strata/?/init.lua;" .. package.path

require("default.hypr.envs")
require("default.hypr.autostart")
require("default.hypr.input")
require("default.hypr.gestures")
require("default.hypr.looknfeel")
-- The theme's generated Lua overrides the fallback border palette above.
-- This file is produced by Strata from theme colors and changes on theme set.
local state_home = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
pcall(dofile, state_home .. "/strata/current/theme/hyprland.lua")
require("default.hypr.monitors")
require("default.hypr.windows")
require("default.hypr.bindings")

local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
pcall(dofile, config_home .. "/hypr/monitors.lua")

-- Add personal overrides below this line.
