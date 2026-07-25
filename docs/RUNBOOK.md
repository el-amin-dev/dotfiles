# Runbook — dotfiles

> Commands only. Not rationale. Not architecture.
> Every command here MUST work as-typed on a fresh clone.
> If behavior changes → this file changes in the SAME PR.
>
> Rationale lives in [DECISIONS.md](DECISIONS.md). Layout and philosophy live in the READMEs.

## Setup

One-time bootstrap on a fresh machine:

```bash
mkdir -p ~/projects
git clone https://github.com/el-amin-dev/dotfiles.git ~/projects/dotfiles
cd ~/projects/dotfiles/zshprofile
chmod +x install.sh
./install.sh
```

`install.sh` is idempotent — safe to re-run; it skips anything already present. It installs the apt
packages, clones Oh My Zsh / Spaceship / plugins into `zshprofile/external/` (git-ignored), installs
FiraCode Nerd Font, symlinks `~/.zshrc` → the repo, and sets zsh as the default shell.

The **only** footprint in `$HOME` is the `~/.zshrc` symlink. An existing regular `~/.zshrc` is moved
to `~/.zshrc.pre-dotfiles` first.

After it finishes, set your terminal font to **FiraCode Nerd Font** manually, then:

```bash
exec zsh
```

## Run

```bash
exec zsh                 # reload the shell cleanly (also aliased: reload)
zshconf                  # open this config repo in $EDITOR (also: zshrc)
```

Machine-specific settings that must not be committed go in a git-ignored file, sourced last so it
wins over every module:

```bash
$EDITOR ~/projects/dotfiles/zshprofile/local/local.zsh
```

## Test

```bash
./tests/test-syntax.sh   # full suite — 30 checks, exit 0 = all passed
```

Covers: every module parses (`zsh -n`), the profile loads with a clean exit status, modules glob in
numeric order, `sh`-executed integrations (`$MANPAGER`, `$FZF_*`) name binaries that actually exist
on this distro, no standard tool is shadowed (ADR-002), and history options match ADR-005.

Run a single check group by reading the section headers in the script; there is no filter flag.

## Database

_(not applicable — no database)_

## Lint / Format

```bash
# Parse-check one file without executing it
zsh -n zshprofile/modules/60-aliases.zsh

# Parse-check everything (also covered by the test suite)
for f in zshprofile/.zshrc zshprofile/modules/[0-9]*.zsh; do zsh -n "$f" || echo "FAIL $f"; done

# Shell-script lint for the bash files, if shellcheck is installed
shellcheck zshprofile/install.sh tests/test-syntax.sh
```

Formatting is governed by `.editorconfig` (2-space indent, LF, trailing newline).

## Smoke checks

Verify the profile loads in isolation, without touching the current shell:

```bash
ZDOTDIR=~/projects/dotfiles/zshprofile zsh -i -c 'exit 0'; echo "exit=$?"
```

`exit=0` is required — a non-zero status is what paints a phantom `✘ 1` on the first prompt of every
new terminal.

Confirm the alias-free integrations resolved to real binaries (these are run by `sh`, which has no
access to shell aliases — on Debian/Ubuntu they must say `fdfind`/`batcat`):

```bash
zsh -i -c 'echo "fd=$ZSH_FD_BIN bat=$ZSH_BAT_BIN"; echo "$FZF_DEFAULT_COMMAND"; echo "$MANPAGER"'
```

Confirm no standard tool was shadowed, and that history matches ADR-005:

```bash
zsh -i -c 'alias cat grep 2>/dev/null; setopt | grep -E "sharehistory|incappend"'
```

Expected: no `cat` alias, `grep` colour-only with **no** `--exclude-dir`, `incappendhistorytime`
present, `sharehistory` absent.

Interactive spot-checks:

```bash
z -            # zoxide jump (cd stays the builtin — see ADR-004)
bat  README.md # plain, copy-paste-safe
batn README.md # line numbers + git gutter + header
man zsh        # rendered through bat, paged
```

## Services / Ports

_(not applicable — no services)_

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Phantom `✘ 1` on the first prompt of every terminal | A test or `&&` chain at the end of `.zshrc` or the last module leaked a non-zero exit status | `.zshrc` ends with a bare `true`; use an `if` block, never `[[ -r f ]] && source f`, as the last statement of a file |
| `zoxide: detected a possible configuration issue` | zoxide's `chpwd` hook was dropped by a later module rebuilding `$chpwd_functions` | zoxide must init last — it lives in `modules/95-zoxide.zsh`, after the 90 prompt. Do **not** silence with `_ZO_DOCTOR=0` (ADR-004) |
| `z` never jumps anywhere useful | Same as above — the database was never being written | Verify `modules/95-zoxide.zsh` loads, then rebuild usage by `cd`-ing around normally |
| fzf is slow, or its file preview is empty | `$FZF_DEFAULT_COMMAND` / preview strings are run by `sh` and cannot use aliases; they named `fd`/`bat`, which don't exist on Debian/Ubuntu | Use `$ZSH_FD_BIN` / `$ZSH_BAT_BIN` (ADR-003). Check with the smoke command above |
| `man` pages unstyled, or dump without paging | `$MANPAGER` named `bat` (alias-only on Debian/Ubuntu), or `bat.conf`'s `--paging=never` leaked in | `$MANPAGER` uses `$ZSH_BAT_BIN` and forces `--paging=always` (`00-env.zsh`) |
| `grep -r` finds nothing in `.venv` / `.git` | Oh My Zsh aliases `grep` with `--exclude-dir={…}` | `60-aliases.zsh` redefines it colour-only (ADR-002). Confirm with `alias grep` |
| Pressing Up shows commands from a *different* terminal | `SHARE_HISTORY` — Oh My Zsh enables it in `lib/history.zsh` | `30-history.zsh` carries an explicit `unsetopt SHARE_HISTORY` (ADR-005) |
| History lost when a terminal is closed or an SSH session drops | Default zsh only flushes history on clean exit | `setopt INC_APPEND_HISTORY_TIME` in `30-history.zsh` (ADR-005) |
| `>` refuses to overwrite a file | `unsetopt CLOBBER` — deliberate (`20-options.zsh`) | Use `>|` to force, or `>>` to append |
| `!` in a command breaks, or "event not found" | History expansion | `setopt NO_BANG_HIST` is set; `!` is literal. `sudo !!` is replaced by the `sudo` plugin's Esc-Esc |
| `cat file` no longer prints colour | `cat`→`bat` alias was removed deliberately (ADR-002) | Use `bat file`, or `batn` for line numbers |
| Ctrl-S freezes the terminal | Legacy XON/XOFF flow control | `unsetopt FLOW_CONTROL` is set; press Ctrl-Q to unfreeze an already-stuck terminal |
| Prompt symbols render as boxes / `?` | Terminal font is not a Nerd Font | Set the terminal font to **FiraCode Nerd Font** (installed by `install.sh`) |
| Changes to a module have no effect | The shell caches nothing, but you are still in the old session | `exec zsh` |
| Completions stale after installing a new tool | zcompdump cache | `rm -f zshprofile/cache/zcompdump* && exec zsh` |
