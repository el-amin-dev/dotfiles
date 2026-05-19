# ════════════════════════════════════════════════════════════════════
#  20-options — setopt: how the shell itself behaves
#  No dependencies. Pure behavior toggles.
# ════════════════════════════════════════════════════════════════════

# ── Directory navigation ───────────────────────────────────────────
setopt AUTO_CD              # type a dir name alone → cd into it
setopt AUTO_PUSHD           # every cd pushes onto the dir stack
setopt PUSHD_IGNORE_DUPS    # no duplicate entries in the stack
setopt PUSHD_SILENT         # don't print the stack after pushd/popd
setopt CDABLE_VARS          # cd into a var if it names a dir

# ── Globbing / pattern matching ────────────────────────────────────
setopt EXTENDED_GLOB        # ^ # ~ qualifiers, negation, etc.
setopt GLOB_DOTS            # globs match dotfiles too (no leading .)
setopt NUMERIC_GLOB_SORT    # file9 < file10  (sort numbers naturally)
setopt NO_CASE_GLOB         # case-insensitive globbing
unsetopt NOMATCH            # a no-match glob passes through, not error

# ── Safety / correctness ───────────────────────────────────────────
setopt CORRECT              # offer to fix mistyped commands
setopt INTERACTIVE_COMMENTS # allow # comments when typing interactively
setopt RM_STAR_WAIT         # 10s pause before 'rm *' executes
unsetopt CLOBBER            # '>' won't overwrite existing files…
                            # …use '>|' to force. Prevents accidents.

# ── Job control / misc ─────────────────────────────────────────────
setopt LONG_LIST_JOBS       # verbose job list (PID + state)
setopt NOTIFY               # report bg job status immediately
setopt NO_BEEP              # stop the terminal bell
setopt MULTIOS              # multiple redirections in one command
setopt PIPE_FAIL            # pipeline fails if ANY stage fails
