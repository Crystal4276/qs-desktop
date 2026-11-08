-- Run inside onMap, before the compositor can render the new window.
-- The observer publishes only process identities and the primary output, never paths.
local runtime = os.getenv('XDG_RUNTIME_DIR')
if not runtime then return end
local sources = {deluge=true, ['deluge-gtk']=true, thunderbird=true, steam=true, steamwebhelper=true}
local own = {deluge=true, ['org.mozilla.thunderbird']=true, thunderbird=true, steam=true}
local consumed, timers = {}, {}
local function read(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local value = f:read('*a'); f:close(); return value
end
local function identity(pid)
    local value = read('/proc/'..tostring(pid)..'/stat')
    if not value then return nil end
    local name, tail = value:match('^%d+ %((.*)%) (.*)$')
    if not tail then return nil end
    local fields = {}; for field in tail:gmatch('%S+') do fields[#fields+1] = field end
    return {name=name:lower(), parent=tonumber(fields[2]), start=fields[20]}
end
local function ancestry(pid)
    local seen = {}
    for _=1,40 do
        if not pid or seen[pid] then return false end
        seen[pid] = true
        local row = identity(pid)
        if not row then return false end
        if sources[row.name] then return true end
        pid = row.parent
    end
    return false
end
local function origin(window, state)
    local row = identity(window.pid)
    if not row then return false end
    local now = tonumber((read('/proc/uptime') or ''):match('^[%d.]+'))
    for token, until_ in pairs(consumed) do
        if not now or until_<=now then consumed[token]=nil end
    end
    for pid, start, until_ in state:gmatch('\n(%d+) (%d+) ([%d.]+)') do
        local token = pid..':'..start..':'..until_
        if tonumber(pid)==window.pid and start==row.start and now and now<tonumber(until_) and not consumed[token] then
            consumed[token] = tonumber(until_)
            return true
        end
    end
    -- An old viewer's parent must not redirect its later, manually opened windows.
    for _, other in ipairs(hl.get_windows()) do
        if other.pid==window.pid and other.address~=window.address then return false end
    end
    if ancestry(window.pid) then return true end
    local env = read('/proc/'..tostring(window.pid)..'/environ') or ''
    local source = env:match('DESKTOP_STARTUP_ID=deluge%-gtk[-_](%d+)[-_]') or env:match('DESKTOP_STARTUP_ID=deluge[-_](%d+)[-_]')
    return source and ancestry(tonumber(source))
end
function qsPlaceExternal(selector, primary)
    local window = hl.get_window(selector)
    if not window or not hl.get_monitor(primary) then return end
    if window.monitor.name==primary then
        hl.dispatch(hl.dsp.focus({window=selector}))
        return
    end
    hl.dispatch(hl.dsp.window.set_prop({window=selector, prop='no_anim', value='true'}))
    hl.dispatch(hl.dsp.window.move({window=selector, monitor=primary, follow=true}))
    hl.dispatch(hl.dsp.focus({window=selector}))
    -- Let the animation manager settle at the destination, then restore configured effects.
    if timers[selector] then timers[selector]:set_enabled(false) end
    timers[selector] = hl.timer(function()
        if hl.get_window(selector) then
            hl.dispatch(hl.dsp.window.set_prop({window=selector, prop='no_anim', value='unset'}))
        end
        timers[selector] = nil
    end, {timeout=100, type='oneshot'})
end
hl.on('window.open', function(window)
    if own[window.class:lower()] then return end
    local state = read(runtime..'/qs-open-origin.state')
    if not state or not origin(window, state) then return end
    local primary = state:match('^([^\n]+)\n')
    if primary then qsPlaceExternal('address:'..window.address, primary) end
end)
