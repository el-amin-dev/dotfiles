# ════════════════════════════════════════════════════════════════════
#  20-options — setopt: how the shell itself behaves.
#  No dependencies. Pure behaviour toggles, zero startup cost.
# ════════════════════════════════════════════════════════════════════

# ── Directory navigation ───────────────────────────────────────────
setopt AUTO_CD              # a bare directory name → cd into it
setopt AUTO_PUSHD           # every cd pushes onto the directory stack
setopt PUSHD_IGNORE_DUPS    # no duplicate entries in the stack
setopt PUSHD_SILENT         # don't print the stack after pushd/popd
setopt CDABLE_VARS          # cd into a variable that names a directory

# ── Globbing / pattern matching ────────────────────────────────────
setopt EXTENDED_GLOB        # ^ # ~ qualifiers, negation, etc.
setopt GLOB_DOTS            # globs match dotfiles without a leading .
setopt NUMERIC_GLOB_SORT    # file9 sorts before file10
setopt NO_CASE_GLOB         # case-insensitive globbing
unsetopt NOMATCH            # a no-match glob is passed through literally
                            # rather than aborting the command

# ── Terminal ───────────────────────────────────────────────────────
unsetopt FLOW_CONTROL       # free Ctrl-S / Ctrl-Q.
                            # Legacy XON/XOFF flow control makes Ctrl-S
                            # FREEZE the terminal with no indication of
                            # why, and Ctrl-Q the only way out. Nothing
                            # needs it on a modern terminal, and it
                            # collides with the near-universal
                            # "Ctrl-S = save" reflex.
setopt NO_BEEP              # no terminal bell
setopt INTERACTIVE_COMMENTS # allow # comments on the interactive line

# ── History expansion ──────────────────────────────────────────────
setopt NO_BANG_HIST         # `!` is a literal character, not history
                            # expansion. Without this, any command
                            # containing `!` — a password, a URL, a
                            # JSON negation, `git commit -m "fixed!"` —
                            # can be silently rewritten or fail with
                            # "event not found".

# ── Guarded destructive operations ─────────────────────────────────
setopt RM_STAR_WAIT         # 10-second pause before a bare `rm *` runs
unsetopt CLOBBER            # `>` refuses to truncate an existing file.
                            # Use `>|` to force, or `>>` to append.
                            # This one is a deliberate trade: it costs
                            # an occasional `>|` in exchange for making
                            # accidental single-keystroke data loss
                            # impossible. Delete this line to restore
                            # the standard behaviour.

# ── Job control ────────────────────────────────────────────────────
setopt LONG_LIST_JOBS       # verbose job list (PID + state)
setopt NOTIFY               # report background job status immediately
setopt MULTIOS              # allow multiple redirections per command

# ── Deliberately NOT set ───────────────────────────────────────────
# The two options below look attractive and are both actively harmful
# in an interactive shell. They are listed so the omission reads as a
# decision rather than an oversight.
#
#   CORRECT     Prompts "did you mean ...?" on anything it does not
#               recognise, including every deliberate typo-shaped
#               command and every binary it has not indexed yet. The
#               prompt interrupts the flow far more often than it helps.
#
#   PIPE_FAIL   Makes a pipeline return the first non-zero exit status
#               from ANY stage. That sounds strictly safer, but it
#               reports failure for the most ordinary idiom there is:
#               in `seq 1 100000 | head -2`, head exits after two
#               lines, seq is killed by SIGPIPE, and the pipeline
#               returns 141. With an exit code in the prompt, every
#               `... | head` and every `... | grep -q` leaves a red
#               failure marker behind. Scripts that need the strict
#               behaviour should set it themselves.
