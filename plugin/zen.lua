-- zen: one pane with nothing around it.
--
-- leader z (or `:zen` in the palette) toggles zen on the workspace shown:
--   the focused pane goes fullscreen (zen.fullscreen), so the other tiles
--   and a monocle tab strip are hidden;
--   the bar is emptied and toolbars put away (zen.bar);
--   with zen.monocle, workspaces that follow the `layout` setting are laid
--   out in monocle, so moving focus still shows one pane at a time.
-- Leaving it puts back what was there: the fullscreen state the workspace
-- had, the bar and toolbars, the layout. `:zen on` and `:zen off` do one
-- way only. ranma.emit("zen", { on = true|false }) as it goes in and out.
--
-- Going to another workspace or session ends zen there and then. The pane
-- fullscreened by zen is put back the next time that workspace is shown.
-- A config reload keeps zen on (the state is in ranma.store("zen")); a new
-- or upgraded server starts with it off.
--
-- What ranma 0.1.0 cannot do from a plugin, so zen does not:
--   hide the bar's row: a profile can empty the bar but not move it to
--     `bar.position = "hidden"`, a theme key, and themes are read at load;
--   hide borders or gaps: `border.style` and `gaps.*` are theme keys too;
--   give back a profile you were using: nothing says which one is in use,
--     so leaving zen goes back to none (what init.lua sets).
--
-- ranma's plugin API: https://github.com/masshirodev/ranma/blob/main/doc/CONFIG.md ("Profiles",
-- "Hooks", "Commands", "A plugin's state").

ranma.option("zen.bar", {
  type = "enum", choices = { "empty", "mode", "keep" }, default = "empty",
  name = "Bar", desc = "In zen: empty the bar and put toolbars away, keep only the mode chip "
    .. "(so WM mode still shows), or leave both as they are.",
})
ranma.option("zen.fullscreen", {
  type = "bool", default = true,
  name = "Fullscreen", desc = "In zen: the focused pane fills the workspace, the others hidden.",
})
ranma.option("zen.monocle", {
  type = "bool", default = false,
  name = "Monocle", desc = "In zen: workspaces that follow the layout setting are laid out "
    .. "in monocle, one pane at a time as focus moves.",
})

-- Options set in init.lua are not known yet while plugins load, so every
-- combination is declared now and the one wanted is picked on the way in.
local BARS = {
  empty = { bar = { left = {}, center = {}, right = {} }, toolbars = {} },
  mode = { bar = { left = { "mode" }, center = {}, right = {} }, toolbars = {} },
  keep = {},
}
local function profile_name(bar, monocle)
  if bar == "keep" and not monocle then return nil end
  return "zen" .. (bar == "empty" and "" or "." .. bar) .. (monocle and ".monocle" or "")
end
for bar, def in pairs(BARS) do
  for _, monocle in ipairs({ false, true }) do
    local name = profile_name(bar, monocle)
    if name then
      ranma.profile(name, {
        bar = def.bar, toolbars = def.toolbars,
        set = monocle and { layout = "monocle" } or nil,
      })
    end
  end
end

local store = ranma.store("zen")
-- Between a fullscreen toggle and the deferred look at what it did.
local busy = false

-- `on`: zen is on, in `session`'s workspace `workspace`; `toggled`: zen
-- turned that workspace's fullscreen on, so leaving turns it off; `profile`:
-- the profile zen put in use. `pending`: "session:workspace" keys whose
-- fullscreen zen turned on and could not take back, as the user had left.
local Z
local function blank()
  return { on = false, pending = {} }
end
local function save()
  store:set("state", Z)
end

-- A reload runs config_reload before anything else reaches this file; any
-- other first call means a server that started (or upgraded) since zen
-- last saved, whose profile and panes are not the ones saved.
local function ready()
  if not Z then
    Z = blank()
    save()
  end
end
ranma.on("config_reload", function()
  Z = store:get("state") or blank()
  Z.pending = Z.pending or {}
end)

local function area()
  local p = ranma.pane()
  return p and p.cols * p.rows or 0
end

-- `fullscreen` only toggles, and nothing reads a workspace's state, so the
-- focused pane's size tells: it grows when fullscreen goes on and shrinks
-- when it goes off. A pane's size is updated once the Lua that moved it
-- returns, hence the defer. One the same size either way (alone on its
-- workspace) is toggled and counted, which keeps the parity right when it
-- is undone.

-- Turn fullscreen on; done(true) if zen did, and so must turn it off.
local function fullscreen_on(done)
  local before = area()
  ranma.action("fullscreen")
  ranma.defer(0, function()
    if area() < before then
      ranma.action("fullscreen")
      return done(false)
    end
    done(true)
  end)
end

-- Turn off the fullscreen zen turned on, unless the user already did.
local function fullscreen_off()
  local before = area()
  ranma.action("fullscreen")
  ranma.defer(0, function()
    if area() > before then ranma.action("fullscreen") end
  end)
end

local function here()
  local s = ranma.state()
  return s.session, s.workspace
end

local function emit(on)
  pcall(ranma.emit, "zen", { on = on })
end

local function enter()
  local session, ws = here()
  if ws == 0 then return ranma.notify("zen: hide the scratchpad first") end
  if not ranma.pane() then return ranma.notify("zen: no pane here") end
  local full, monocle = ranma.get("zen.fullscreen"), ranma.get("zen.monocle")
  local profile = profile_name(ranma.get("zen.bar"), monocle)
  if not full and not profile then
    return ranma.notify("zen: every zen option is off; nothing to hide")
  end
  -- The profile first: monocle's tab strip is part of what fullscreen hides.
  if profile then ranma.use_profile(profile) end
  Z.on, Z.session, Z.workspace, Z.profile, Z.toggled = true, session, ws, profile, false
  save()
  emit(true)
  if full then
    busy = true
    fullscreen_on(function(did)
      busy = false
      -- Left again before the answer came: the undo is the workspace's.
      if did and not Z.on then
        Z.pending[session .. ":" .. ws] = true
      else
        Z.toggled = did
      end
      save()
    end)
  end
end

-- `away`: the user is on another workspace now, where fullscreen is not
-- zen's to touch; it is taken back when they return.
local function leave(away)
  if Z.toggled then
    if away then
      Z.pending[Z.session .. ":" .. Z.workspace] = true
    else
      fullscreen_off()
    end
  end
  if Z.profile then ranma.use_profile(nil) end
  Z.on, Z.session, Z.workspace, Z.toggled, Z.profile = false, nil, nil, nil, nil
  save()
  emit(false)
end

local function zen(want)
  ready()
  if busy then return end
  if want == nil then want = not Z.on end
  if want == Z.on then return end
  if want then return enter() end
  local _, ws = here()
  if ws == 0 then return ranma.notify("zen: hide the scratchpad first") end
  leave(false)
end

-- Somewhere else: zen ends. Back on a workspace zen left fullscreen: undo it.
local function moved()
  ready()
  local session, ws = here()
  if ws == 0 then return end
  if Z.on and (session ~= Z.session or ws ~= Z.workspace) then
    local was = Z.workspace
    leave(true)
    ranma.notify("zen: off, as workspace " .. was .. " was left")
  end
  local key = session .. ":" .. ws
  if Z.pending[key] then
    Z.pending[key] = nil
    fullscreen_off()
    save()
  end
end
ranma.on("workspace_change", moved)
ranma.on("session_switch", moved)

ranma.command("zen", function(arg)
  arg = arg and arg:match("^%s*(.-)%s*$") or ""
  if arg == "" then return zen(nil) end
  if arg == "on" then return zen(true) end
  if arg == "off" then return zen(false) end
  ranma.notify("zen: on, off, or nothing to toggle")
end, { desc = "one pane with nothing around it", args = "[on|off]", complete = { "on", "off" } })

-- WM mode ends with it: with the bar emptied, nothing would say it is on.
ranma.bind("z", function() zen(nil) end, { desc = "zen", exit = true })
