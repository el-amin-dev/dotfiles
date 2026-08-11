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

Commands shipped by this repo live in `zshprofile/bin/`, which `00-env.zsh` puts on `$PATH`:

```bash
my-computer                    # hardware, software and live status report
my-computer --all              # verbose: virtual interfaces, swap at 0%, locale, cache
my-computer --ascii            # ASCII frame and meters (non-UTF-8 terminals)
my-computer --no-color         # plain text, also automatic when piped
my-computer --no-banner        # skip the block-letter banner
my-computer --banner HELLO     # render different banner text
my-computer --width 80         # override the auto-detected width
my-computer --help

asciify "HELLO"                # block-letter art, pure zsh
echo HI | asciify --trim       # reads stdin too
asciify --char '#' "ASCII"     # ASCII-safe glyph
asciify --width 40 "FITS?"     # prints nothing, exits 1, if wider than 40
```

`my-computer` draws its banner by calling `asciify`; if `asciify` is missing or the render would be
wider than the terminal, it falls back to a boxed header without comment.

An **ATTENTION** section appears at the end *only when something needs doing* — a pending reboot, a
filesystem past 90%, a CPU at 85°C, or a battery below 65% of design capacity. On a healthy machine
it is absent entirely, so its presence always means something.

`my-computer` needs no system-info package: it reads `/proc`, `/sys` and `/etc/os-release` on Linux,
and `sysctl`/`sw_vers`/`vm_stat`/`pmset` on macOS. Anything the platform will not report shows as a
dash rather than failing the report.

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

> **Shell hangs at startup?** Run `./tests/diagnose-startup.sh` on that machine. Every check is
> timeouted, so the script cannot hang the way the shell does — a check that times out *is* the
> answer, and it prints what to do about it.

| Symptom | Cause | Fix |
|---|---|---|
| Terminal accepts no input until Ctrl-C; `source ~/.zshrc` hangs too; an interrupted prompt leaves a literal `$(spaceship::rprompt)` on screen | `HIST_FCNTL_LOCK` with `$HISTFILE` on a **network** filesystem. `fcntl()` locking over NFS/SMB blocks with no error and no timeout when the server's lock manager is unreachable. Hits managed/corporate machines with a roaming `$HOME`; reinstalling never helps because the filesystem is the variable, not the config | Already handled — `30-history.zsh` enables the lock only on local storage (ADR-006). Confirm with `./tests/diagnose-startup.sh`. To force it off by hand, put `unsetopt HIST_FCNTL_LOCK` in `local/local.zsh` |
| Shell state lives on a network mount and everything is slow | `$HOME`/repo is network-mounted | `export ZSH_CACHE_DIR=/var/tmp/zsh-$USER` in `local/local.zsh` |
| Prompt renders half-drawn, or stalls before accepting input | Spaceship's async worker never reports back — endpoint-security agents on managed machines can make fork/exec pathologically slow | `SPACESHIP_PROMPT_ASYNC=false` in `local/local.zsh` |
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
| A `~/.zcompdump` keeps reappearing in `$HOME` | Debian/Ubuntu run a bare `compinit` from `/etc/zsh/zshrc`, which is sourced *before* `~/.zshrc` and cannot see anything this repo sets | Known, harmless duplicate; `tests/test-syntax.sh` reports it as WARN. The documented opt-out is `skip_global_compinit=1`, but it must live in `~/.zshenv` and this repo installs only `~/.zshrc`. Safe to delete the file; it will be recreated |
