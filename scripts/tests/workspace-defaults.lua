-- Run with: luajit scripts/tests/workspace-defaults.lua
-- Exercise the actual workspace reconciler without a compositor or real state.
local source = "defaults/hypr/workspaces.lua"
local state = os.tmpname()
os.remove(state)
local function scenario(ids, occupied, saved)
    os.remove(state)
    rawset(_G, "__strata_workspace_state_path", state)
    local monitors, workspaces, rules = {}, {}, {}
    for i, id in ipairs(ids) do
        local monitor = {id=i-1, name="display-" .. i}
        local workspace = {id=id, name=tostring(id), monitor=monitor}
        monitor.active_workspace = workspace
        monitors[i], workspaces[i] = monitor, workspace
    end
    if saved then
        local file = assert(io.open(state, "w"))
        for i, slot in pairs(saved) do file:write("A\tdisplay-", i, "\t", slot, "\n") end
        file:close()
    end
    local focused = monitors[1]
    hl = {
        on=function() end,
        timer=function() return {set_enabled=function() end} end,
        get_monitors=function() return monitors end,
        get_workspaces=function() return workspaces end,
        get_active_monitor=function() return focused end,
        get_active_window=function() return nil end,
        get_workspace_windows=function(id)
            if occupied and tonumber(id) == ids[2] then return {{stable_id=1}} end
            return {}
        end,
        workspace_rule=function(rule)
            rules[#rules+1] = rule
            return {set_enabled=function() end}
        end,
        dsp={
            focus=function(args) return {kind="focus", args=args} end,
            window={move=function(args) return {kind="move-window", args=args} end},
            workspace={move=function(args) return {kind="move-workspace", args=args} end},
        },
        dispatch=function(action)
            if action.kind ~= "focus" then return end
            if action.args.monitor then focused=action.args.monitor end
            if action.args.workspace then
                local id=tonumber(action.args.workspace)
                local workspace={id=id, name=tostring(id), monitor=focused}
                focused.active_workspace=workspace
                workspaces[#workspaces+1]=workspace
            end
        end,
    }
    local module=dofile(source)
    assert(module.reconcile())
    for _, monitor in ipairs(monitors) do
        local defaults=0
        for _, rule in ipairs(rules) do
            if rule.monitor == monitor.name and rule.default then
                defaults=defaults+1
                assert(tonumber(rule.workspace)==module.base(monitor)+1)
            end
        end
        assert(defaults==1, "each output needs one default at local desktop 1")
    end
    return module, monitors
end
local function run()
    local module, monitors=scenario({1,2})
    assert(monitors[1].active_workspace.id==101)
    assert(monitors[2].active_workspace.id==201, "external bootstrap must start at local 1")
    -- Reconciliation must not reset an explicit later workspace selection.
    monitors[2].active_workspace={id=203, name="203", monitor=monitors[2]}
    assert(module.reconcile())
    assert(monitors[2].active_workspace.id==203)
    _, monitors=scenario({1,2}, true)
    assert(monitors[2].active_workspace.id==202, "occupied legacy desktop must retain its number")
    _, monitors=scenario({1,2}, false, {[2]=4})
    assert(monitors[2].active_workspace.id==204, "remembered reconnect selection must survive")
    _, monitors=scenario({1,2,3})
    assert(monitors[3].active_workspace.id==301, "third output must also start at local 1")
    _, monitors=scenario({1})
    assert(monitors[1].active_workspace.id==101)
    _, monitors=scenario({105,202})
    assert(monitors[1].active_workspace.id==105 and monitors[2].active_workspace.id==202,
        "existing local desktops must not be reset on config reload")
end
local ok, err=pcall(run)
os.remove(state)
os.remove(state .. ".new")
rawset(_G, "__strata_workspace_state_path", nil)
if not ok then error(err) end
print("PASS: new displays start at local 1; occupied, selected and restored desktops are preserved")
