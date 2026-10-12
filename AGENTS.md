# AGENTS.md

zen.ranma is a ranma plugin in Lua: `plugin/zen.lua` is all of it, and
its header comment is the reference that `README.md` repeats. ranma's API is
https://github.com/masshirodev/ranma/blob/main/doc/CONFIG.md (`ranma --dump-types` prints it as LuaLS annotations).

- Push to `main`.
- A change to what it does changes the header comment and `README.md` in the
  same commit, and an option goes in the README's table.
- Use only what the latest ranma release has: CI loads the plugin into it.
  zen needs ranma 0.2.2 (profile themes, `fullscreen on|off`, and
  `profile` and `fullscreen` in `ranma.state()`); the README's "How it works"
  section says what each carries and what is still missing.
- Check it loads: `ranma --check-config` lists every plugin and why one failed;
  `ranma lua` runs code in the live server.
  CI (`.github/workflows/ci.yml`) loads it into the latest ranma release on
  every push and fails if it does not.
- Test behaviour on a private server, never the one your terminal runs in:
  unset `RANMA_SOCKET RANMA RANMA_PANE TMUX`, point `RANMA_CONFIG_DIR` and
  the `XDG_*` directories at a temp dir, and drive ranma in a private tmux
  (`tmux -L <name>`), as ranma's `scripts/smoke.sh` does. Cases worth
  repeating: every combination of options (read the frame with `tmux
  capture-pane`: no bar row, no border, no gap), a profile already in use
  before zen (given back exactly), already fullscreen before zen, focus
  moved during zen, leaving the workspace and coming back, a session switch,
  a reload during zen, and a fresh server whose store still says zen is on.
- `AGENTS.local.md` (gitignored) carries what is true of one checkout on one
  machine. Never commit it.
