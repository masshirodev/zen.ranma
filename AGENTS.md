# AGENTS.md

zen.ranma is a ranma plugin in Lua: `plugin/zen.lua` is all of it, and
its header comment is the reference that `README.md` repeats. ranma's API is
https://github.com/masshirodev/ranma/blob/main/doc/CONFIG.md (`ranma --dump-types` prints it as LuaLS annotations).

- Push to `main`.
- A change to what it does changes the header comment and `README.md` in the
  same commit, and an option goes in the README's table.
- Use only what the latest ranma release has: CI loads the plugin into it.
  zen leans on three facts of ranma 0.1.0 that a newer ranma may change, and
  the README's "How it works" section says why each matters: `ranma.set` and
  theme keys cannot change at run time (so the bar row, borders and gaps
  stay); nothing reports whether a workspace is fullscreen or which profile
  is in use; a pane's size is updated only after the Lua that resized it
  returns (so the check is a `ranma.defer`).
- Check it loads: `ranma --check-config` lists every plugin and why one failed;
  `ranma lua` runs code in the live server.
  CI (`.github/workflows/ci.yml`) loads it into the latest ranma release on
  every push and fails if it does not.
- Test behaviour on a private server, never the one your terminal runs in:
  unset `RANMA_SOCKET RANMA RANMA_PANE TMUX`, point `RANMA_CONFIG_DIR` and the
  `XDG_*` directories at a temp dir, and drive ranma in a private tmux
  (`tmux -L <name>`), as ranma's `scripts/smoke.sh` does. Cases worth
  repeating: already fullscreen before zen, focus moved during zen, leaving
  the workspace and coming back, a session switch, a reload during zen, and
  a fresh server whose store still says zen is on.
- `AGENTS.local.md` (gitignored) carries what is true of one checkout on one
  machine. Never commit it.
