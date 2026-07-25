# ════════════════════════════════════════════════════════════════════
#  95-zoxide — frecency-based directory jumping. MUST LOAD LAST.
#
#  Two deliberate decisions are encoded in this file. Both fix real,
#  daily-visible problems, so neither should be undone casually.
#
#  ── 1. It loads last (95, after the prompt in 90) ──────────────────
#  zoxide learns directories through a `chpwd` hook that it appends to
#  $chpwd_functions. Anything sourced afterwards that rebuilds that
#  array — a prompt framework registering its own chpwd handler, for
#  instance — can drop zoxide's hook. When that happens zoxide silently
#  stops recording anywhere you go: the database never grows, so `z`
#  never has anything useful to jump to, and zoxide's own startup check
#  begins printing
#
#      zoxide: detected a possible configuration issue.
#      Please ensure that zoxide is initialized right at the end of
#      your shell configuration file (usually ~/.zshrc).
#
#  Initialising after every other module is the actual fix. Suppressing
#  the warning with _ZO_DOCTOR=0 would hide a broken install instead.
#
#  ── 2. `cd` is left alone ─────────────────────────────────────────
#  zoxide can be initialised with `--cmd cd`, which replaces the `cd`
#  builtin with a function that jumps to a remembered directory when
#  the literal path does not exist. That is a bad trade in a shell that
#  also has AUTO_CD and NOMATCH disabled: a mistyped path stops being
#  an error and becomes a silent jump to a plausible-looking directory
#  somewhere else on the disk — which is genuinely dangerous when the
#  next command in the buffer is destructive.
#
#  So `cd` stays the builtin: it either goes exactly where it was told
#  or it fails. Jumping is opt-in, by its own name:
#
#      z  <keyword>   jump to the best-matching known directory
#      zi <keyword>   choose interactively from all matches
#      j  <keyword>   alias for z (60-aliases.zsh)
# ════════════════════════════════════════════════════════════════════

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi
