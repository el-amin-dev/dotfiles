# Architecture Decision Records

> Append-only. One entry per significant decision. Newest on top.
> "Significant" = affects architecture, data model, security posture, or is hard to reverse.

<!--
Entry format (use exactly this shape):

## ADR-NNN — <title> (<date>)
- status: accepted | superseded-by-ADR-NNN
- context: <what forced a decision>
- decision: <what was chosen>
- alternatives: <what was rejected + why>
- consequences: <trade-offs accepted>
-->

<!-- append ADRs below, newest first -->

## ADR-006 — History file locking is conditional on the filesystem (2026-07-25)
- status: accepted
- context: ADR-005 added `HIST_FCNTL_LOCK` so concurrent terminals cannot corrupt the history file.
  That is correct and effectively free on local storage. It is a trap on a network filesystem:
  `fcntl()` locking over NFS or SMB is serviced by the server's lock manager, and when that manager
  is unreachable, not running, or the export disallows locking, the call **blocks with no error and
  no timeout**. The shell then stops before it can accept a keystroke.
  Observed on one of four otherwise identical Ubuntu machines — a managed corporate system with a
  network-mounted home. Symptoms: the terminal took no input until Ctrl-C, `source ~/.zshrc` hung
  the same way, and the interrupted prompt sometimes left a literal `$(spaceship::rprompt)` on
  screen where the theme had not finished rendering. Reinstalling never helped, because the variable
  was the filesystem, not the configuration.
- decision: Enable `HIST_FCNTL_LOCK` only when `$HISTFILE` sits on local storage, detected with
  `stat -f -c %T` at startup. Network and userspace filesystems (nfs, smb, cifs, fuse, afs, 9p,
  gluster, lustre, ceph) and any type that cannot be determined leave the option off. `local/local.zsh`
  can force it either way. `tests/diagnose-startup.sh` reproduces and confirms the failure, and the
  suite asserts the decision matches the filesystem on whichever machine it runs.
- alternatives:
  - Leave it on everywhere — rejected; that is the bug, and its failure mode is a shell that will
    not accept input, which reads as a broken machine rather than a broken setting.
  - Remove it everywhere — rejected; it discards real protection on the three machines where
    locking works, to accommodate one where it does not.
  - Wrap history writes in a timeout — rejected; there is no supported way to bound the syscall from
    inside zsh, and a partially written history file is worse than an unlocked one.
  - Move `$HISTFILE` to local storage unconditionally — rejected as the default, since it would put
    shell state outside the repo and break the portability the layout exists for. It stays available
    as a documented `local/local.zsh` override for anyone who wants locking on such a machine.
- consequences: One `stat` call (~3.5 ms) per shell startup, never per prompt. Machines with a
  network home keep durable history via `INC_APPEND_HISTORY_TIME` but lose corruption protection
  when several terminals write at once — an acceptable trade against a shell that hangs. The
  detection is Linux-specific: `stat -f -c` is GNU coreutils, and on a system without it the guard
  falls through to leaving locking off, which is the safe direction.

## ADR-005 — History is written incrementally, never shared live between terminals (2026-07-25)
- status: accepted
- context: With zsh's defaults, history is flushed only when a shell exits cleanly. Closing a
  terminal window, a crash, or a dropped SSH session therefore discards everything typed in that
  session, and a terminal opened right now cannot see anything typed in another one. Both are
  daily-visible losses.
- decision: Set `INC_APPEND_HISTORY_TIME` so each command is appended once it *finishes* (which
  also records its duration), plus `HIST_FCNTL_LOCK` so concurrent terminals appending to the same
  file lock it properly. `EXTENDED_HISTORY` is required for the timestamp format and is set too.
- alternatives:
  - `SHARE_HISTORY` — rejected. It live-imports other terminals' commands into this session, so
    pressing Up returns a line typed in a different window. That breaks the per-terminal mental
    model of "Up = what *I* just did here", which is the primary way history is used.
  - Plain `INC_APPEND_HISTORY` — rejected. Appends before the command runs, so no duration is
    recorded and `history -i` cannot show elapsed time.
  - Leaving the default (flush on exit) — rejected; that is the bug being fixed.
- consequences: A command is only visible to *other* terminals after it completes, so a
  long-running command is not in the shared file while it runs. `HISTSIZE`/`SAVEHIST` of 50000 costs
  a few MB on disk and nothing at startup, since zsh reads the file lazily.
  **`SHARE_HISTORY` must be disabled explicitly, not merely left unset.** Oh My Zsh turns it on in
  `lib/history.zsh`, which module 10 sources before this module runs, so `30-history.zsh` carries an
  explicit `unsetopt SHARE_HISTORY`. This was caught by `tests/test-syntax.sh`, not by review — the
  module documented the intent while the runtime did the opposite.

## ADR-004 — zoxide initialises last, and `cd` remains the shell builtin (2026-07-25)
- status: accepted
- context: Two independent failures. (1) zoxide learns directories through a `chpwd` hook appended
  to `$chpwd_functions`; anything sourced afterwards that rebuilds that array — such as a prompt
  framework registering its own handler — silently drops it. zoxide then records nothing, `z` never
  has a useful target, and zoxide's own doctor check starts printing a configuration warning.
  (2) zoxide can be initialised with `--cmd cd`, replacing the `cd` builtin with a function that
  jumps to a remembered directory when the literal path does not exist.
- decision: Move zoxide out of `80-tools.zsh` into its own `95-zoxide.zsh`, loading after the prompt
  module (90), and initialise with a bare `zoxide init zsh`. Jumping is opt-in by its own name:
  `z`, `zi`, and the `j` alias.
- alternatives:
  - Keep zoxide in `80-tools.zsh` and silence the warning with `_ZO_DOCTOR=0` — rejected; that hides
    a genuinely broken install rather than fixing it.
  - Keep `--cmd cd` — rejected. This config also sets `AUTO_CD` and unsets `NOMATCH`, so a mistyped
    path already fails softly; adding a fuzzy `cd` turns a typo into a *silent jump* to a
    plausible-looking directory elsewhere on disk. That is dangerous when the next command in the
    buffer is destructive.
- consequences: `cd` either goes exactly where it was told or fails, which is the point. Users must
  learn a second verb (`z`) to get frecency jumping. Module numbering now reserves 95+ for anything
  that must observe hooks registered by every earlier module.

## ADR-003 — Real binary names are resolved once for contexts that bypass aliases (2026-07-25)
- status: accepted
- context: Debian and Ubuntu ship `fd` as `fdfind` and `bat` as `batcat` due to unrelated name
  clashes. Aliases cover typing those names interactively, but aliases are a shell-level convenience
  that does **not** exist for anything executed outside the interactive shell — and several
  integrations here are exactly that: `$FZF_DEFAULT_COMMAND` and `$FZF_ALT_C_COMMAND` are run by fzf
  itself, fzf `--preview` strings are run via `sh -c`, and `$MANPAGER` is run via `sh -c`. Each one
  degraded *silently* on a Debian-family machine: fzf fell back to its slower built-in directory
  walker, and file previews rendered empty.
- decision: Resolve the real binary name once in `00-env.zsh` into exported `$ZSH_FD_BIN` and
  `$ZSH_BAT_BIN`, and build every non-interactive integration on those variables. Each is exported
  so subshells and preview commands can read it. When a tool is absent the variable is empty and the
  dependent integration is simply not configured — `man`, for instance, keeps its own pager.
- alternatives:
  - Hardcode `fd`/`bat` — rejected; that is the bug.
  - Hardcode `fdfind`/`batcat` — rejected; breaks on Arch, Fedora, macOS and any build from source.
  - Rely on the aliases — rejected; aliases are not inherited by `sh -c`.
- consequences: One extra `$+commands` probe per tool at startup (negligible, no subprocess). Two
  more exported variables in the environment. New integrations must remember to use `$ZSH_BAT_BIN`
  rather than `bat`; this is called out in the comments at both definition and use sites.

## ADR-002 — Modern CLI tools do not shadow their standard counterparts (2026-07-25)
- status: accepted
- context: The previous aliases rebound `cat` to `bat` and `grep` to `rg`. Both replacements are
  *not* drop-in: `rg` recurses by default, silently skips hidden and `.gitignore`'d files, and uses
  a different regex dialect; `bat` breaks `cat -v`, `cat -A`, `cat -n`, `cat -s`, `cat -e`, reading
  from stdin, and any pasted script that expects `cat` to behave like `cat`. The failure mode of
  aliasing `grep`→`rg` is the worst kind available: a familiar command returns **fewer results with
  no error**, so the user trusts an incomplete answer.
- decision: Standard tools keep their standard behaviour and their standard flags. Modern
  replacements are reached by their own names, with extra capability exposed under new names rather
  than by overloading old ones: `bat` / `batn` / `batp`, and `rg` / `rga` / `rgf`.
- alternatives:
  - Keep the shadowing aliases — rejected for the reasons above.
  - Shadow but add escape hatches (`\cat`, `command grep`) — rejected; the escape hatch only helps
    someone who has already noticed the problem, and the `grep` case gives no signal that anything
    is wrong.
- consequences: Two deliberate exceptions, both documented inline at their definition.
  (1) `ls`→`eza`: it accepts the flags people actually type interactively (`-l`, `-a`, `-h`) and its
  output is only ever read by a human, never parsed. (2) `rm`/`cp`/`mv`/`mkdir` gain additive prompt
  flags (`-I`, `-i`, `-pv`): no behaviour is removed, only guarded, and the standard form is one
  backslash away. Muscle memory built on `cat file` producing colour must be relearned as `bat file`.
  Removing the offending aliases from `60-aliases.zsh` is **not sufficient on its own**: Oh My Zsh's
  `lib/grep.zsh` independently aliases `grep`, `egrep` and `fgrep` with
  `--exclude-dir={…,.git,.venv,venv,…}`, reintroducing exactly this failure mode — a recursive grep
  that quietly skips whole directories. `60-aliases.zsh` therefore redefines all three as
  colour-only, keeping the additive half and discarding the result-filtering half. The rule is
  enforced at runtime by `tests/test-syntax.sh`, which asserts each alias still resolves to its own
  binary and adds no `--exclude`/`--ignore` flag.

## ADR-001 — Numbered zsh modules behind a loader-only `.zshrc` (2026-05-19, recorded retroactively)
- status: accepted
- context: A single monolithic `.zshrc` gives no answer to "when does X happen relative to Y", which
  matters because several components here are order-sensitive: plugins must load before their
  runtime tuning, syntax highlighting must wrap ZLE widgets last, and hook-registering tools must
  see the final state of `$chpwd_functions`.
- decision: `.zshrc` contains a loader loop and nothing else. All configuration lives in
  `modules/NN-name.zsh`, sourced in numeric order, one concern per file. Machine-specific settings
  go in `local/local.zsh` (git-ignored), sourced last so it wins over every module.
- alternatives:
  - Monolithic `.zshrc` — rejected; load order becomes implicit and invisible.
  - A framework's own module system — rejected; couples the whole config to that framework's
    lifetime, and Oh My Zsh is only one of the pieces being ordered here.
- consequences: Load order is encoded in filenames, so it is visible from `ls` and the loader never
  needs editing when modules are added. Renumbering a module is a rename, not a code change. The
  cost is more files, and the discipline that nothing may be added to `.zshrc` itself.
