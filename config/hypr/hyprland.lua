-- Strata defaults are owned by the RPM. Personal Lua below the requires
-- always wins and is never replaced during package upgrades.
package.path = "/usr/share/strata/?.lua;/usr/share/strata/?/init.lua;" .. package.path

require("default.hypr.envs")
require("default.hypr.autostart")
require("default.hypr.input")
require("default.hypr.looknfeel")
require("default.hypr.monitors")
require("default.hypr.windows")
require("default.hypr.bindings")

local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
pcall(dofile, config_home .. "/hypr/monitors.lua")

-- Add personal overrides below this line.
