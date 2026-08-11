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

# ── File locking: ONLY on a local filesystem ───────────────────────
# HIST_FCNTL_LOCK makes zsh take an fcntl() lock around history writes,
# which is the correct way to stop several terminals corrupting the file
# and costs nothing on a local disk.
#
# On a NETWORK filesystem it is a trap. fcntl() locking over NFS or SMB
# is handled by the server's lock manager, and when that is unreachable,
# not running, or the export disallows locking, the call BLOCKS — no
# error, no timeout. The shell stops before it can accept a keystroke,
# and Ctrl-C is the only escape, because interrupting the syscall is
# precisely what Ctrl-C does. `source ~/.zshrc` hangs the same way, and
# an interrupted prompt can leave a literal $(spaceship::rprompt) on
# screen where the theme had not finished rendering.
#
# This bites exactly one class of machine: managed/corporate systems
# with a roaming or network-mounted $HOME. Identical config, identical
# install, one machine hangs — because the filesystem differs, which is
# why reinstalling never helped.
#
# So the option is enabled only when the history file is on local
# storage. `stat -f` costs about a millisecond, once per shell, and only
# at startup — never per prompt.
#
# To force it either way, in local/local.zsh:
#     setopt HIST_FCNTL_LOCK      # or:  unsetopt HIST_FCNTL_LOCK
#
# Diagnose a suspected hang with:  ./tests/diagnose-startup.sh
if (( $+commands[stat] )); then
  case "${$(stat -f -c %T ${HISTFILE:h} 2>/dev/null):-unknown}" in
    # Network and userspace filesystems — locking may block. Leave off.
    nfs*|smb*|cifs*|fuse*|afs*|9p*|glusterfs|lustre*|ceph*|unknown) ;;
    # Local filesystems — locking is safe and wanted.
    *) setopt HIST_FCNTL_LOCK ;;
  esac
fi

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
