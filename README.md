# zen.ranma

A plugin for [ranma](https://github.com/masshirodev/ranma), the terminal tiling window manager: a distraction-free mode, one pane with nothing around it.

## Install

With [hako](https://github.com/masshirodev/hako.ranma), in `~/.config/ranma/lua/plugins/zen.lua`:

```lua
return { "masshirodev/zen.ranma" }
```

Or by hand, as ranma loads any package under `pack/*/start/`:

```sh
git clone https://github.com/masshirodev/zen.ranma ~/.config/ranma/pack/plugins/start/zen.ranma
```

Needs: ranma 0.2.2 or newer (profile themes, `fullscreen on|off`, and the profile and fullscreen state in `ranma.state()`).

## What it does

```text
zen: one pane with nothing around it.

leader z (or `:zen` in the palette) toggles zen on the workspace shown:
  the focused pane goes fullscreen (zen.fullscreen), so the other tiles
  and a monocle tab strip are hidden;
  the bar's row goes and toolbars are put away (zen.bar);
  pane borders and gaps go (zen.borders, zen.gaps);
  with zen.monocle, workspaces that follow the `layout` setting are laid
  out in monocle, so moving focus still shows one pane at a time.
Leaving it puts back what was there: the fullscreen state the workspace
had, the bar, toolbars, borders, gaps and layout, and the profile that was
in use (the mobile view, say). `:zen on` and `:zen off` do one way only.
ranma.emit("zen", { on = true|false }) as it goes in and out.

Going to another workspace or session ends zen there and then. The pane
fullscreened by zen is put back the next time that workspace is shown.
A config reload keeps zen on (the state is in ranma.store("zen")); a new
or upgraded server starts with it off.
```

## Keys and commands

| | |
| --- | --- |
| `leader z` | Toggle zen on the workspace shown. WM mode ends with it. |
| `:zen` | The same, from the palette. |
| `:zen on`, `:zen off` | One way only. |

`ranma.unbind("z")` in `init.lua` drops the key; `:zen` stays in the palette.

## Options

In ranma's settings panel under `zen`, or with hako's `opts` (`{ "masshirodev/zen.ranma", opts = { ... } }`), or `ranma.set { zen = { ... } }`.

| Option | Default | |
| --- | --- | --- |
| `zen.bar` | `"empty"` | `empty`: no bar at all, its row included, and toolbars put away. `mode`: only the mode chip, so WM mode still shows. `keep`: the bar and toolbars as they are. |
| `zen.borders` | `false` | Keep pane borders in zen. Off, they go (`border.style = "none"` while zen is on). |
| `zen.gaps` | `false` | Keep the gaps around and between panes in zen. Off, every gap is 0 while zen is on. |
| `zen.fullscreen` | `true` | The focused pane fills the workspace, the others hidden. |
| `zen.monocle` | `false` | Workspaces that follow the `layout` setting are laid out in monocle while zen is on, so moving focus still shows one pane at a time. A workspace given its own layout with `workspace_layout` keeps it. |

Options are read each time zen starts, so a change applies from the next one.

## How it works, and its limits

- **A profile** carries the frame: the bar's row and toolbars, borders and gaps (theme keys a profile sets while it is in use), and monocle. Profiles are declared while ranma loads, before `init.lua` sets zen's options, so zen declares one per combination of options (`zen`, `zen.mode`, `zen.keep.monocle.borders`, ...: the name says what differs from the defaults) and uses the one the options ask for. The profile in use before it, read from `ranma.state().profile`, is given back on the way out, so the mobile view survives zen.
- **The `fullscreen on` and `fullscreen off` actions** for the pane, and `ranma.state().fullscreen` to know whether the workspace was fullscreen already. Leaving zen undoes only what zen did.

What follows from that:

- **zen's profile is used instead of the one in use**, not over it: profiles do not stack, so the mobile view's settings are away while zen is on and come back with it off. A profile something else picks while zen is on (a `driver_change` hook choosing the mobile view when a phone starts driving) is left alone when zen ends, and it ends zen's frame while the pane stays fullscreen; `leader z` twice puts zen back.
- **Messages need the bar**: ranma shows them in the bar's centre, so with `zen.bar = "empty"` ranma's own messages are not seen while zen is on. zen's own are toasts while it is on.
- **Monocle stays a profile setting**, not `workspace_layout`: a profile is undone by switching away from it and is gone on a new server, while a workspace's own layout is kept across upgrades and in the restore snapshot, so a zen cut short would leave the workspace in monocle for good. The price is that a workspace given its own layout keeps it in zen.
- **Going to another workspace or session ends zen.** Fullscreen is per workspace and set on the one shown, so a pane zen made fullscreen is put back when you next show its workspace. The scratchpad is not leaving: zen stays while it shows, and toggling zen waits until it is hidden.
- **A config reload keeps zen on**: ranma keeps the profile in use, and zen reads its state back from `ranma.store("zen")`. A new server, or one upgraded in place, starts with zen off.

Other plugins can follow zen: `ranma.on("user:zen", function(e) ... end)` hears `{ on = true }` and `{ on = false }`.

## License

MIT or Apache-2.0, as ranma.
