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

Needs: Nothing beyond ranma.

## What it does

```text
zen: one pane with nothing around it.

leader z (or `:zen` in the palette) toggles zen on the workspace shown:
  the focused pane goes fullscreen (zen.fullscreen), so the other tiles
  and a monocle tab strip are hidden;
  the bar is emptied and toolbars put away (zen.bar);
  with zen.monocle, workspaces that follow the `layout` setting are laid
  out in monocle, so moving focus still shows one pane at a time.
Leaving it puts back what was there: the fullscreen state the workspace
had, the bar and toolbars, the layout. `:zen on` and `:zen off` do one
way only. ranma.emit("zen", { on = true|false }) as it goes in and out.

Going to another workspace or session ends zen there and then. The pane
fullscreened by zen is put back the next time that workspace is shown.
A config reload keeps zen on (the state is in ranma.store("zen")); a new
or upgraded server starts with it off.

What ranma 0.1.0 cannot do from a plugin, so zen does not:
  hide the bar's row: a profile can empty the bar but not move it to
    `bar.position = "hidden"`, a theme key, and themes are read at load;
  hide borders or gaps: `border.style` and `gaps.*` are theme keys too;
  give back a profile you were using: nothing says which one is in use,
    so leaving zen goes back to none (what init.lua sets).
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
| `zen.bar` | `"empty"` | `empty`: the bar shows nothing and toolbars are put away. `mode`: only the mode chip, so WM mode still shows. `keep`: both as they are. |
| `zen.fullscreen` | `true` | The focused pane fills the workspace, the others hidden. |
| `zen.monocle` | `false` | Workspaces that follow the `layout` setting are laid out in monocle while zen is on, so moving focus still shows one pane at a time. A workspace given its own layout with `workspace_layout` keeps it. |

Options are read each time zen starts, so a change applies from the next one.

## How it works, and its limits

ranma 0.1.0 lets a plugin change little at run time: `ranma.set` is for loading only, and theme keys are read once. zen uses the two things it can:

- **The `fullscreen` action** for the pane. It only toggles, and nothing reports whether a workspace is fullscreen, so zen toggles it and looks at the pane's size a moment later: a pane that shrank was fullscreen already and is toggled back. Leaving zen undoes only what zen did.
- **A profile** for the bar, toolbars and monocle. zen declares `zen`, `zen.mode`, `zen.monocle`, `zen.mode.monocle` and `zen.keep.monocle`, one per combination of options, and uses the one the options ask for. Leaving goes back to no profile, which gives back exactly what `init.lua` set.

What follows from that:

- **The bar's row stays**, empty. Removing it is `bar.position = "hidden"`, a theme key.
- **Borders and gaps stay.** `border.style` and `gaps.*` are theme keys too. If you want zen without them, set them in your theme for good; zen cannot change them for a while.
- **A profile you were using is replaced**, and leaving zen goes back to none, as nothing tells a plugin which profile is in use. A `driver_change` hook that picks a profile (the mobile view) picks again the next time a terminal starts driving, which also ends zen's bar and layout while the pane stays fullscreen; `leader z` twice puts zen back.
- **Going to another workspace or session ends zen.** Fullscreen is per workspace and can only be toggled on the one shown, so a pane zen made fullscreen is put back when you next show its workspace. The scratchpad is not leaving: zen stays while it shows, and toggling zen waits until it is hidden.
- **A config reload keeps zen on**: ranma keeps the profile in use, and zen reads its state back from `ranma.store("zen")`. A new server, or one upgraded in place, starts with zen off.

Other plugins can follow zen: `ranma.on("user:zen", function(e) ... end)` hears `{ on = true }` and `{ on = false }`.

## License

MIT or Apache-2.0, as ranma.
