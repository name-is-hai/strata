-- Local desktop numbers, backed by distinct Hyprland IDs on each output.
-- Keep this arithmetic in sync with shell/Commons/WorkspaceNumbers.js.
local M = {}
local hidden_prefix = "special:strata-desktop-"
local busy = false
local rules, rule_signature = {}, nil
local last_active, previous = {}, {}
local connected = {}

function M.base(monitor) return (monitor.id + 1) * 100 end
function M.owns(monitor, id)
    return monitor and id > M.base(monitor) and id < M.base(monitor) + 100
end
function M.number(id) return id % 100 end
function M.monitor(name)
    if name then
        for _, m in ipairs(hl.get_monitors() or {}) do if m.name == name then return m end end
        return nil
    end
    return hl.get_active_monitor()
end
local function activate(monitor, id)
    -- The shipped Hyprland's monitor:set_workspace only switches to existing
    -- workspaces. The focus dispatcher also creates an empty desktop.
    hl.dispatch(hl.dsp.focus({ monitor = monitor }))
    hl.dispatch(hl.dsp.focus({ workspace = tostring(id), on_current_monitor = true }))
end
local function windows(id) return hl.get_workspace_windows(tostring(id)) or {} end
local function parked_workspace(workspace)
    return workspace and type(workspace.name) == "string"
        and workspace.name:match("^special:strata%-desktop%-%d+$") ~= nil
end
local function close_parked_workspace(monitor)
    if monitor and monitor.active_workspace and parked_workspace(monitor.active_special_workspace) then
        monitor:set_special_workspace({})
        return true
    end
    return false
end

-- Parking is an implementation detail of Show Desktop. Native output moves
-- or last-window focus recovery can open a special workspace; close parking
-- immediately, without changing normal scratchpad behavior.
hl.on("workspace.special_active", function(workspace, monitor)
    if parked_workspace(workspace) then close_parked_workspace(monitor or workspace.monitor) end
end)

function M.occupied(id)
    return #windows(id) > 0 or #windows(hidden_prefix .. id) > 0
end

-- Keep a window's home while it is temporarily evacuated. Runtime storage
-- survives theme/config reloads, but is deliberately discarded on logout.
local state_path = rawget(_G, "__strata_workspace_state_path")
    or ((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/strata-workspace-homes-" .. (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "session") .. ".tsv")
local homes, saved_active = {}, {}
local function valid_name(name) return type(name) == "string" and name:match("^[%w_.:-]+$") end
local function window_key(window)
    local id = window.stable_id
    return id and tostring(id) or nil
end
local function topology(monitors)
    local names = {}
    for _, m in ipairs(monitors) do names[#names + 1] = m.id .. ":" .. m.name end
    table.sort(names)
    return table.concat(names, "|")
end
local function write_homes()
    local file = io.open(state_path .. ".new", "w")
    if not file then return end
    for name, slot in pairs(saved_active) do
        if valid_name(name) then file:write("A\t", name, "\t", slot, "\n") end
    end
    for key, home in pairs(homes) do
        if key:match("^%d+$") and valid_name(home.name) then
            file:write("W\t", key, "\t", home.name, "\t", home.slot, "\t", home.parked and "1" or "0",
                "\t", home.guest_monitor or "-", "\t", home.guest_id or 0, "\n")
        end
    end
    file:close()
    os.rename(state_path .. ".new", state_path)
end
do
    local file = io.open(state_path, "r")
    if file then
        for line in file:lines() do
            local name, slot = line:match("^A\t([%w_.:-]+)\t(%d+)$")
            if name and tonumber(slot) > 0 and tonumber(slot) < 100 then saved_active[name] = tonumber(slot) end
            local key, owner, number, parked, guest, id = line:match("^W\t(%d+)\t([%w_.:-]+)\t(%d+)\t([01])\t([%w_.:-]+)\t(%d+)$")
            if key and tonumber(number) > 0 and tonumber(number) < 100 then
                homes[key] = { name=owner, slot=tonumber(number), parked=parked == "1",
                    guest_monitor=guest ~= "-" and guest or nil, guest_id=tonumber(id) > 0 and tonumber(id) or nil }
            end
        end
        file:close()
    end
end
local function guest_workspace(name, id, returning)
    for _, home in pairs(homes) do
        if home.guest_id == id and (home.guest_monitor == name or returning)
            and (not returning or M.monitor(home.name)) then return true end
    end
    return false
end
local function remember()
    if busy or topology(hl.get_monitors() or {}) ~= rule_signature then return end
    local seen = {}
    for _, ws in ipairs(hl.get_workspaces() or {}) do
        local id = ws.id > 0 and ws.id or tonumber((ws.name or ""):match("^special:strata%-desktop%-(%d+)$"))
        for _, w in ipairs(windows(ws.id > 0 and ws.id or ws.name)) do
            local key = window_key(w)
            if key then
                seen[key] = true
                if id and M.owns(ws.monitor, id) then
                    local home = homes[key]
                    if home and not M.monitor(home.name) then
                        home.guest_monitor, home.guest_id = ws.monitor.name, id
                        home.parked = ws.id < 0
                    else
                        homes[key] = { name=ws.monitor.name, slot=M.number(id), parked=ws.id < 0 }
                    end
                elseif not id then homes[key] = nil end
            end
        end
    end
    for key in pairs(homes) do if not seen[key] then homes[key] = nil end end
    for _, monitor in ipairs(hl.get_monitors() or {}) do
        local id = monitor.active_workspace and monitor.active_workspace.id
        if id and M.owns(monitor, id) and not guest_workspace(monitor.name, id) then
            saved_active[monitor.name] = M.number(id)
        end
    end
    write_homes()
end

-- Adopt legacy desktops and desktops evacuated by monitor hot-unplug. Snapshot
-- each group before moving it; hidden desktop windows must stay hidden.
function M.reconcile()
    if busy then return end
    busy = true
    local ok, err = pcall(function()
        local monitors, all = hl.get_monitors() or {}, hl.get_workspaces() or {}
        local signature = topology(monitors)
        if signature ~= rule_signature then
            for _, rule in ipairs(rules) do rule:set_enabled(false) end
            rules = {}
            for _, m in ipairs(monitors) do
                for slot = 1, 99 do
                    rules[#rules + 1] = hl.workspace_rule({
                        workspace = tostring(M.base(m) + slot), monitor = m.name, default = slot == 1,
                    })
                end
            end
            rule_signature = signature
        end
        local changed = false
        for _, monitor in ipairs(monitors) do
            if close_parked_workspace(monitor) then changed = true end
        end
        local focused = hl.get_active_window()
        local focused_monitor = hl.get_active_monitor()
        local restore_active = {}
        local next_connected = {}
        for _, m in ipairs(monitors) do
            next_connected[m.name] = m.id
            local id = m.active_workspace and m.active_workspace.id
            if not connected[m.name] and saved_active[m.name] and not guest_workspace(m.name, id) then
                restore_active[m.name] = saved_active[m.name]
            end
        end
        -- Remember whether a surviving output is still showing an evacuated
        -- desktop. If so, restore its own previous desktop on reconnection too.
        for _, m in ipairs(monitors) do
            local id = m.active_workspace and m.active_workspace.id
            if id and guest_workspace(m.name, id, true) then restore_active[m.name] = saved_active[m.name] end
        end
        local returned = false
        for _, ws in ipairs(all) do
            for _, w in ipairs(windows(ws.id > 0 and ws.id or ws.name)) do
                local key = window_key(w)
                local home = key and homes[key]
                local owner = home and home.guest_monitor and M.monitor(home.name)
                if owner then
                    local id = M.base(owner) + home.slot
                    local target = home.parked and (hidden_prefix .. id) or tostring(id)
                    hl.dispatch(hl.dsp.window.move({ window=w, workspace=target, follow=false }))
                    hl.dispatch(hl.dsp.workspace.move({ workspace=target, monitor=owner }))
                    restore_active[owner.name] = saved_active[owner.name] or home.slot
                    home.guest_monitor, home.guest_id = nil, nil
                    returned = true
                end
            end
        end
        if returned then all = hl.get_workspaces() or {} end
        local groups, used = {}, {}
        for _, ws in ipairs(all) do
            local id = ws.id > 0 and ws.id or tonumber((ws.name or ""):match("^special:strata%-desktop%-(%d+)$"))
            if id and ws.monitor then
                local key = ws.monitor.name .. ":" .. id
                local g = groups[key] or { id = id, monitor = ws.monitor, visible = {}, hidden = {} }
                groups[key] = g
                if ws.id > 0 then g.visible = windows(id) else g.hidden = windows(ws.name) end
                used[id] = true
            end
        end
        local active = {}
        for _, m in ipairs(monitors) do
            active[m.name] = restore_active[m.name] and (M.base(m) + restore_active[m.name])
                or (m.active_workspace and m.active_workspace.id)
        end
        local pending = {}
        for _, g in pairs(groups) do
            if not M.owns(g.monitor, g.id) and (#g.visible > 0 or #g.hidden > 0 or active[g.monitor.name] == g.id) then
                pending[#pending + 1] = g
            end
        end
        table.sort(pending, function(a, b) return a.id < b.id end)
        for _, g in ipairs(pending) do
            local base = M.base(g.monitor)
            local slot = M.number(g.id)
            -- Hyprland initially gives outputs global desktops 1, 2, ... . An
            -- empty bootstrap desktop is local desktop 1 on every output, not
            -- the output's position in that global allocation. Keep occupied
            -- legacy desktops and remembered reconnect selections intact.
            if g.id > 0 and g.id < 100 and not connected[g.monitor.name]
                and not saved_active[g.monitor.name] and active[g.monitor.name] == g.id
                and #g.visible == 0 and #g.hidden == 0 then slot = 1 end
            if slot < 1 or (used[base + slot] and (#g.visible > 0 or #g.hidden > 0)) then
                slot = 1
                while slot < 100 and used[base + slot] do slot = slot + 1 end
            end
            if slot >= 100 then error("No free local workspace on " .. g.monitor.name) end
            local target = base + slot
            used[target] = true
            for _, w in ipairs(g.visible) do
                hl.dispatch(hl.dsp.window.move({ window = w, workspace = tostring(target), follow = false }))
            end
            for _, w in ipairs(g.hidden) do
                hl.dispatch(hl.dsp.window.move({ window = w, workspace = hidden_prefix .. target, follow = false }))
            end
            if #g.visible > 0 then
                hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(target), monitor = g.monitor }))
            end
            if #g.hidden > 0 then
                hl.dispatch(hl.dsp.workspace.move({ workspace = hidden_prefix .. target, monitor = g.monitor }))
            end
            if active[g.monitor.name] == g.id then active[g.monitor.name] = target end
        end
        for _, m in ipairs(monitors) do
            local id = active[m.name]
            if not id or not M.owns(m, id) then id = M.base(m) + 1 end
            if not m.active_workspace or m.active_workspace.id ~= id then activate(m, id); changed = true end
        end
        connected = next_connected
        if focused and not parked_workspace(focused.workspace) and (changed or returned or #pending > 0) then hl.dispatch(hl.dsp.focus({ window = focused }))
        elseif changed and focused_monitor then hl.dispatch(hl.dsp.focus({ monitor = focused_monitor })) end
    end)
    busy = false
    if not ok then print("Strata workspaces: " .. tostring(err)) else remember() end
    return ok
end

function M.select(number, name)
    local monitor = M.monitor(name)
    if not monitor or type(number) ~= "number" or number < 1 or number > 99 or number % 1 ~= 0 then return end
    activate(monitor, M.base(monitor) + number)
end
-- Preview and execution share this allocation policy: preserve the local
-- number when unused, otherwise take the first free number on the destination.
function M.destination(id, name)
    local monitor = M.monitor(name)
    if not monitor or type(id) ~= "number" or id < 1 then return nil end
    local used = {}
    for _, ws in ipairs(hl.get_workspaces() or {}) do
        local number = ws.id > 0 and ws.id or tonumber((ws.name or ""):match("^special:strata%-desktop%-(%d+)$"))
        if number then used[number] = true end
    end
    local slot = M.number(id)
    if slot == 0 or used[M.base(monitor) + slot] then
        slot = 1
        while slot < 100 and used[M.base(monitor) + slot] do slot = slot + 1 end
    end
    return slot < 100 and (M.base(monitor) + slot) or nil
end

function M.transfer(id, name, preferred_slot)
    if type(id) ~= "number" or id < 1 or id % 1 ~= 0 then return nil end
    local target = M.monitor(name)
    local source
    for _, monitor in ipairs(hl.get_monitors() or {}) do if M.owns(monitor, id) then source = monitor end end
    if busy or not source or not target or source.name == target.name then return nil end
    local destination = M.destination(id, name)
    -- An RDP handoff remembers each workspace's original local number. Its
    -- empty replacement desktop can be reused when that workspace returns.
    if type(preferred_slot) == "number" and preferred_slot >= 1 and preferred_slot <= 99
        and preferred_slot % 1 == 0 and not M.occupied(M.base(target) + preferred_slot) then
        destination = M.base(target) + preferred_slot
    end
    if not destination then return nil end
    local visible, hidden = windows(id), windows(hidden_prefix .. id)
    local follow = source.active_workspace and source.active_workspace.id == id
    busy = true
    local ok, err = pcall(function()
        for _, group in ipairs({ {windows=visible, parked=false}, {windows=hidden, parked=true} }) do
            local selector = group.parked and (hidden_prefix .. destination) or tostring(destination)
            for _, window in ipairs(group.windows) do
                hl.dispatch(hl.dsp.window.move({ window=window, workspace=selector, follow=false }))
                local key = window_key(window)
                if key then homes[key] = {name=target.name, slot=M.number(destination), parked=group.parked} end
            end
            if #group.windows > 0 then hl.dispatch(hl.dsp.workspace.move({workspace=selector, monitor=target})) end
        end
        if follow then
            local fallback
            for _, ws in ipairs(hl.get_workspaces() or {}) do
                if M.owns(source, ws.id) and ws.id ~= id and (not fallback or ws.id < fallback) then fallback = ws.id end
            end
            activate(source, fallback or (M.base(source) + (M.number(id) == 1 and 2 or 1)))
            activate(target, destination)
        end
        if valid_name(source.name) and valid_name(target.name) then
            hl.dispatch(hl.dsp.event("strata.workspace-transfer|" .. source.name .. "|" .. M.number(id)
                .. "|" .. target.name .. "|" .. M.number(destination)))
        end
    end)
    busy = false
    if not ok then print("Strata workspace transfer: " .. tostring(err)); return nil end
    remember()
    return destination
end
function M.transfer_active(direction)
    local source = M.monitor()
    local target = hl.get_monitor(direction)
    if source and source.active_workspace and target then return M.transfer(source.active_workspace.id, target.name) end
end

function M.previous()
    local monitor = M.monitor()
    local id = monitor and previous[monitor.name]
    if id and M.owns(monitor, id) then M.select(M.number(id), monitor.name) end
end
function M.move(number, follow)
    local window = hl.get_active_window()
    local monitor = window and window.monitor or M.monitor()
    if not window or not monitor or number < 1 or number > 99 then return end
    local id = M.base(monitor) + number
    hl.dispatch(hl.dsp.window.move({ window = window, workspace = tostring(id), follow = false }))
    hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = monitor }))
    if follow then M.select(number, monitor.name) end
end
function M.cycle(offset)
    local monitor = M.monitor()
    if not monitor then return end
    local slots = { [1]=true, [2]=true, [3]=true, [4]=true, [5]=true }
    for _, ws in ipairs(hl.get_workspaces() or {}) do
        local id = ws.id > 0 and ws.id or tonumber((ws.name or ""):match("^special:strata%-desktop%-(%d+)$"))
        if id and M.owns(monitor, id) then slots[M.number(id)] = true end
    end
    local ordered = {}
    for n in pairs(slots) do ordered[#ordered + 1] = n end
    table.sort(ordered)
    local current = monitor.active_workspace and M.number(monitor.active_workspace.id) or 1
    for i, n in ipairs(ordered) do
        if n == current then M.select(ordered[(i - 1 + offset) % #ordered + 1], monitor.name); return end
    end
    M.select(1, monitor.name)
end

-- Swipes skip empty gaps toward the nearest occupied (including hidden)
-- desktop. At either end, allow one empty neighbor, never a chain of empties.
function M.swipe(offset)
    local monitor = hl.get_monitor_at_cursor() or M.monitor()
    local current = monitor and monitor.active_workspace
    if not current or not M.owns(monitor, current.id) then return end
    local nearest
    for _, ws in ipairs(hl.get_workspaces() or {}) do
        local id = ws.id > 0 and ws.id or tonumber((ws.name or ""):match("^special:strata%-desktop%-(%d+)$"))
        if id and M.owns(monitor, id) and M.occupied(id) and (id - current.id) * offset > 0
            and (not nearest or (id - nearest) * offset < 0) then nearest = id end
    end
    if not nearest and not M.occupied(current.id) then return end
    local target = nearest or current.id + offset
    if M.owns(monitor, target) then M.select(M.number(target), monitor.name) end
end

hl.on("workspace.active", function(workspace)
    local monitor = workspace and workspace.monitor
    if not monitor or not M.owns(monitor, workspace.id) then return end
    local old = last_active[monitor.name]
    if old and old ~= workspace.id then previous[monitor.name] = old end
    last_active[monitor.name] = workspace.id
    remember()
end)
hl.on("window.move_to_workspace", function(window)
    if busy or topology(hl.get_monitors() or {}) ~= rule_signature then return end
    local key = window_key(window)
    local home = key and homes[key]
    local ws = window.workspace
    -- A deliberate move while unplugged adopts this window on the remaining
    -- output. Automatic evacuation retains the foreign workspace ID here.
    if home and home.guest_monitor and not M.monitor(home.name) and ws and M.owns(ws.monitor, ws.id)
        and (ws.monitor.name ~= home.guest_monitor or ws.id ~= home.guest_id) then homes[key] = nil end
    remember()
end)
for _, event in ipairs({ "window.open", "window.destroy" }) do hl.on(event, remember) end
rawset(_G, "__strata_workspaces", M)
-- Debounce lifecycle changes, after Hyprland finishes moving evacuated windows.
local timer
local function schedule()
    if not busy and timer then timer:set_enabled(true) end
end
timer = hl.timer(function()
    timer:set_enabled(false)
    M.reconcile()
end, { timeout = 150, type = "repeat" })
for _, event in ipairs({ "hyprland.start", "monitor.added", "workspace.move_to_monitor", "workspace.created" }) do
    hl.on(event, schedule)
end
-- Mark displacement at the removal event, before the debounce expires. A
-- reconnect in that interval must still restore the old homes and desktop.
hl.on("monitor.removed", function(monitor)
    local function mark(name, id)
        connected[name] = nil
        for _, home in pairs(homes) do
            if home.name == name then
                home.guest_monitor = home.guest_monitor or name
                home.guest_id = home.guest_id or ((id + 1) * 100 + home.slot)
            end
        end
    end
    if monitor and monitor.name and monitor.id then mark(monitor.name, monitor.id)
    else
        local absent = {}
        for name, id in pairs(connected) do if not M.monitor(name) then absent[name] = id end end
        for name, id in pairs(absent) do mark(name, id) end
    end
    write_homes()
    schedule()
end)
return M
