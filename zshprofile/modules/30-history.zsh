# ════════════════════════════════════════════════════════════════════
#  30-history — how the shell remembers what was typed.
#  $HISTFILE is set in 00-env.zsh → cache/zsh_history (git-ignored).
#  Zero startup cost: variables and setopt only, no subprocesses.
# ════════════════════════════════════════════════════════════════════

# ── Size: a large history is cheap, recall is not ──────────────────
HISTSIZE=50000          # events kept in memory for this session
SAVEHIST=50000          # events written to $HISTFILE
# 50k covers years of use for a few MB on disk, and costs nothing at
# startup: zsh reads the history file lazily rather than parsing it all.

# ── Write immediately, not at exit ─────────────────────────────────
# Without this, history is flushed only when the shell exits cleanly —
# so a closed terminal window, a crash, or a killed SSH session loses
# everything typed in it, and a second terminal opened right now cannot
# see any of it.
#
# INC_APPEND_HISTORY_TIME appends each command once it FINISHES, which
# also records how long it took.
setopt INC_APPEND_HISTORY_TIME
setopt HIST_FCNTL_LOCK         # lock the file properly when several
                               # terminals append at the same time

# SHARE_HISTORY must be turned OFF *explicitly*, not merely left unset.
# Oh My Zsh enables it in lib/history.zsh, which module 10 has already
# sourced by the time this file runs — so omitting it here leaves it ON
# and this module's stated behaviour would be a lie.
#
# It is unwanted because it live-imports other terminals' commands into
# this session: pressing Up returns a line typed in a different window,
# which breaks the per-terminal "Up = what I just did here" model.
# INC_APPEND_HISTORY_TIME above already gives the durability half of
# what SHARE_HISTORY offers, without the cross-talk.
unsetopt SHARE_HISTORY

# ── Deduplication and cleanliness ──────────────────────────────────
setopt HIST_IGNORE_ALL_DUPS    # re-running a command drops the older copy
setopt HIST_SAVE_NO_DUPS       # never write a duplicate event to the file
setopt HIST_REDUCE_BLANKS      # trim redundant whitespace before saving
setopt HIST_VERIFY             # expansions land on the line for review
                               # instead of executing immediately

# ── Keep secrets out of the history file ───────────────────────────
# Any command typed with a leading space is executed but never
# recorded. Use it for anything containing a token or password:
#     ␣export GITHUB_TOKEN=...
setopt HIST_IGNORE_SPACE

# ── Timestamps ─────────────────────────────────────────────────────
# EXTENDED_HISTORY stores ":<start-time>:<elapsed-seconds>;<command>"
# in the file. This is what makes `history -i` show when a command ran,
# and it is required by INC_APPEND_HISTORY_TIME above.
setopt EXTENDED_HISTORY
