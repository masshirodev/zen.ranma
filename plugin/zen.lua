-- zen: one pane with nothing around it.
--
-- Needs ranma 0.2.2 or newer.
--
-- leader z (or `:zen` in the palette) toggles zen on the workspace shown:
--   the focused pane goes fullscreen (zen.fullscreen), so the other tiles
--   and a monocle tab strip are hidden;
--   the bar's row goes and toolbars are put away (zen.bar);
--   pane borders and gaps go (zen.borders, zen.gaps);
--   with zen.monocle, workspaces that follow the `layout` setting are laid
--   out in monocle, so moving focus still shows one pane at a time.
-- Leaving it puts back what was there: the fullscreen state the workspace
-- had, the bar, toolbars, borders, gaps and layout, and the profile that was
-- in use (the mobile view, say). `:zen on` and `:zen off` do one way only.
-- ranma.emit("zen", { on = true|false }) as it goes in and out.
--
-- Going to another workspace or session ends zen there and then. The pane
-- fullscreened by zen is put back the next time that workspace is shown.
-- A config reload keeps zen on (the state is in ranma.store("zen")); a new
-- or upgraded server starts with it off.
--
-- ranma's plugin API: https://github.com/masshirodev/ranma/blob/main/doc/CONFIG.md ("Profiles",
-- "Hooks", "Commands", "A plugin's state").

ranma.option("zen.bar", {
  type = "enum", choices = { "empty", "mode", "keep" }, default = "empty",
  name = "Bar", desc = "In zen: no bar at all (its row goes, toolbars are put away), "
    .. "only the mode chip (so WM mode still shows), or the bar and toolbars as they are.",
})
ranma.option("zen.borders", {
  type = "bool", default = false,
  name = "Borders", desc = "In zen: keep pane borders. Off, they go.",
})
ranma.option("zen.gaps", {
  type = "bool", default = false,
  name = "Gaps", desc = "In zen: keep the gaps around and between panes. Off, they go.",
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

-- Profiles are declared while loading, and plugins load before init.lua sets
-- their options, so one profile per combination is declared now and the one
-- the options ask for is picked on the way in. Its name carries what differs
-- from the defaults: `zen`, `zen.mode`, `zen.keep.monocle.borders`, ...
local BARS = {
  empty = { theme = { bar = { position = "hidden" } }, toolbars = {} },
  mode = { bar = { left = { "mode" }, center = {}, right = {} }, toolbars = {} },
  keep = {},
}
-- Every gap, the per-side ones included: a theme that sets `outer_top` would
-- otherwise keep it over `outer_vertical = 0`.
local NO_GAPS = {
  inner = 0, outer_horizontal = 0, outer_vertical = 0,
  outer_top = 0, outer_bottom = 0, outer_left = 0, outer_right = 0,
}
local function profile_name(bar, monocle, borders, gaps)
  if bar == "keep" and not monocle and borders and gaps then return nil end
  return "zen" .. (bar == "empty" and "" or "." .. bar) .. (monocle and ".monocle" or "")
    .. (borders and ".borders" or "") .. (gaps and ".gaps" or "")
end
local ZEN = {}
for bar, def in pairs(BARS) do
  for _, monocle in ipairs({ false, true }) do
    for _, borders in ipairs({ false, true }) do
      for _, gaps in ipairs({ false, true }) do
        local name = profile_name(bar, monocle, borders, gaps)
        if name then
          local theme = {}
          if def.theme then theme.bar = def.theme.bar end
          if not borders then theme.border = { style = "none" } end
          if not gaps then theme.gaps = NO_GAPS end
          ranma.profile(name, {
            bar = def.bar, toolbars = def.toolbars,
            set = monocle and { layout = "monocle" } or nil,
            theme = next(theme) and theme or nil,
          })
          ZEN[name] = true
        end
      end
    end
  end
end

local store = ranma.store("zen")

-- `on`: zen is on, in `session`'s workspace `workspace`; `toggled`: zen
-- turned that workspace's fullscreen on, so leaving turns it off; `profile`:
-- the profile zen put in use, and `previous` the one in use before it (nil
-- for none). `pending`: "session:workspace" keys whose fullscreen zen turned
-- on and could not take back, as the user had left.
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

-- A message takes the bar's centre, and zen may have taken the bar's row
-- away: while zen is on, its messages are toasts.
local function say(msg)
  if Z and Z.on then return ranma.toast(msg) end
  ranma.notify(msg)
end

local function emit(on)
  pcall(ranma.emit, "zen", { on = on })
end

local function enter()
  local s = ranma.state()
  if s.workspace == 0 then return say("zen: hide the scratchpad first") end
  if not ranma.pane() then return say("zen: no pane here") end
  local full = ranma.get("zen.fullscreen")
  local profile = profile_name(ranma.get("zen.bar"), ranma.get("zen.monocle"),
    ranma.get("zen.borders"), ranma.get("zen.gaps"))
  if not full and not profile then
    return say("zen: every zen option is off; nothing to hide")
  end
  Z.on, Z.session, Z.workspace = true, s.session, s.workspace
  Z.profile, Z.previous = profile, nil
  -- The profile first: monocle's tab strip is part of what fullscreen hides.
  if profile then
    -- One of zen's own still in use means zen's state was lost (a new
    -- server); going back to it on the way out would keep zen's frame.
    if not ZEN[s.profile or ""] then Z.previous = s.profile end
    ranma.use_profile(profile)
  end
  Z.toggled = full and not s.fullscreen
  if Z.toggled then ranma.action("fullscreen on") end
  save()
  emit(true)
end

-- `away`: the user is on another workspace now, where fullscreen is not
-- zen's to touch; it is taken back when they return.
local function leave(away)
  if Z.toggled then
    if away then
      Z.pending[Z.session .. ":" .. Z.workspace] = true
    else
      ranma.action("fullscreen off")
    end
  end
  -- Only zen's own: a profile something else picked since (a driver_change
  -- hook's mobile view) is that hook's choice, and stays.
  if Z.profile and ranma.state().profile == Z.profile then
    ranma.use_profile(Z.previous)
  end
  Z.on, Z.session, Z.workspace, Z.toggled, Z.profile, Z.previous = false, nil, nil, nil, nil, nil
  save()
  emit(false)
end

local function zen(want)
  ready()
  if want == nil then want = not Z.on end
  if want == Z.on then return end
  if want then return enter() end
  if ranma.state().workspace == 0 then return say("zen: hide the scratchpad first") end
  leave(false)
end

-- Somewhere else: zen ends. Back on a workspace zen left fullscreen: undo it.
local function moved()
  ready()
  local s = ranma.state()
  if s.workspace == 0 then return end
  if Z.on and (s.session ~= Z.session or s.workspace ~= Z.workspace) then
    local was = Z.workspace
    leave(true)
    say("zen: off, as workspace " .. was .. " was left")
  end
  local key = s.session .. ":" .. s.workspace
  if Z.pending[key] then
    Z.pending[key] = nil
    ranma.action("fullscreen off")
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
  say("zen: on, off, or nothing to toggle")
end, { desc = "one pane with nothing around it", args = "[on|off]", complete = { "on", "off" } })

-- WM mode ends with it: with the bar emptied, nothing would say it is on.
ranma.bind("z", function() zen(nil) end, { desc = "zen", exit = true })
