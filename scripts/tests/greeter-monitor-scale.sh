#!/usr/bin/env bash
# Execute the real greeter Lua with compositor operations replaced by fixtures.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
luajit - "$repo/defaults/greeter/hyprland.lua" <<'LUA'
local rules, events = {}, {}
local monitors = {{name = "HDMI-A-1"}, {name = "eDP-1"}}
local fixtures = {
    ["/etc/strata/monitor-scales"] = {"HDMI-A-1 1.25", "eDP-1 1.5", "DP-1 0", "DP-2 99", "bad;name 2"},
    ["/etc/strata/disabled-monitors"] = {"eDP-1"},
}
io.open = function(name)
    local lines = fixtures[name]
    if not lines then return nil end
    return {close = function() end, lines = function()
        local i = 0
        return function() i = i + 1; return lines[i] end
    end}
end
os.getenv = function(name) return name == "STRATA_MAIN_MONITOR" and "HDMI-A-1" or nil end
hl = {
    monitor = function(rule) rules[#rules + 1] = rule end,
    on = function(name, callback) events[name] = callback end,
    get_monitors = function() return monitors end,
    config = function() end,
    exec_cmd = function() end,
}
assert(loadfile(arg[1]))()
assert(rules[1].output == "" and rules[1].scale == "auto")
local main
for _, rule in ipairs(rules) do
    if rule.output == "HDMI-A-1" and rule.position == "0x0" then main = rule end
    assert(rule.output ~= "DP-1" and rule.output ~= "DP-2" and rule.output ~= "bad;name")
end
assert(main and main.scale == 1.25, "Main monitor did not retain its desktop scale")
events["hyprland.start"]()
assert(rules[#rules].output == "eDP-1" and rules[#rules].disabled == true)
monitors = {{name = "eDP-1"}}
events["monitor.removed"]()
local fallback = rules[#rules]
assert(fallback.output == "eDP-1" and fallback.disabled == false and fallback.scale == 1.5,
    "Laptop fallback lost its scale or remained disabled")
print("PASS: greeter Main scale, automatic unknown-display scale, invalid rows and laptop-only fallback")
LUA

# Live Apply changes do not emit config.reloaded. Exercise the desktop hook
# itself so a successful greeter policy test cannot hide a missing sync event.
luajit - "$repo/defaults/hypr/monitors.lua" <<'LUA'
local events, commands = {}, {}
hl = {
    monitor = function() end,
    on = function(name, callback)
        events[name] = events[name] or {}
        table.insert(events[name], callback)
    end,
    exec_cmd = function(command) commands[#commands + 1] = command end,
}
assert(loadfile(arg[1]))()
for _, event in ipairs({"hyprland.start", "config.reloaded", "monitor.layout_changed"}) do
    commands = {}
    for _, callback in ipairs(events[event] or {}) do callback() end
    local synced = false
    for _, command in ipairs(commands) do
        if command == "strata-greeter-monitors-sync" then synced = true end
    end
    assert(synced, "Greeter scale was not synchronized on " .. event)
end
print("PASS: greeter scale sync follows login, reload and live layout changes")
LUA
