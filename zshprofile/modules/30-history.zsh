# ════════════════════════════════════════════════════════════════════
#  30-history — how the shell remembers what you typed
#  HISTFILE was set in 00-env → cache/zsh_history (git-ignored)
#  Zero startup cost: only variables + setopt, no subprocesses.
# ════════════════════════════════════════════════════════════════════

# ── Size: big history is cheap; recall is invaluable ───────────────
HISTSIZE=50000          # commands kept in memory this session
SAVEHIST=50000          # commands written to $HISTFILE
# 50k is plenty for years of use and costs ~a few MB. Not a speed hit:
# zsh loads history lazily, it does not parse all 50k at startup.

# ── Deduplication & cleanliness ────────────────────────────────────
setopt HIST_IGNORE_ALL_DUPS    # a command already in history → drop old copy
setopt HIST_SAVE_NO_DUPS       # never write duplicate events to the file
setopt HIST_IGNORE_SPACE       # cmd starting with a space → not recorded
setopt HIST_REDUCE_BLANKS      # trim redundant whitespace before saving
setopt HIST_VERIFY             # expand !! / !$ onto the line, don't run blind

# ── Timestamps ─────────────────────────────────────────────────────
setopt EXTENDED_HISTORY        # store :start
