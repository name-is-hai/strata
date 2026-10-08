local md = {}

function md.bind(keys, description, dispatcher, options)
    local opts = options or {}
    opts.description = description
    if type(dispatcher) == "string" then
        dispatcher = hl.dsp.exec_cmd(dispatcher)
    end
    return hl.bind(keys, dispatcher, opts)
end

-- Mark bindings whose command owns both the on and off transitions.  Keeping
-- this separate from bind() makes toggles easy to find and gives us one place
-- to enforce their naming and behaviour later.
function md.bind_toggle(keys, description, command, options)
    assert(type(command) == "string" and command ~= "", "toggle command must be a non-empty string")
    return md.bind(keys, description, command, options)
end

function md.launch(command)
    return "uwsm app -- " .. command
end

function md.on_start(command)
    hl.on("hyprland.start", function()
        hl.exec_cmd(command)
    end)
end

function md.launch_on_start(command)
    md.on_start(md.launch(command))
end

return md
