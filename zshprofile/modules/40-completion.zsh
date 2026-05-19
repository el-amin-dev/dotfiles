# ════════════════════════════════════════════════════════════════════
#  40-completion — what happens when you press Tab
#  NOTE: Oh My Zsh (10-omz) already calls compinit. We do NOT call it
#  again here — we only (a) steer its dump into cache/ via 00-env-style
#  vars set before OMZ, and (b) tune completion styling after the fact.
#  Zero extra startup cost: zstyle calls are instant, no subprocess.
# ════════════════════════════════════════════════════════════════════

# ── Where the compdump lives (repo cache, git-ignored) ─────────────
# OMZ honors $ZSH_COMPDUMP. We set it here defensively in case OMZ
# re-reads it; the real win is keeping it OUT of $HOME.
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump"

# ── Completion menu behavior ───────────────────────────────────────
zstyle ':completion:*' menu select                 # arrow-key selectable menu
zstyle ':completion:*' group-name ''               # group matches by type
zstyle ':completion:*:descriptions' format \
       '%F{yellow}── %d ──%f'                       # pretty group headers

# ── Matching: case-insensitive + smart partial matching ────────────
# lowercase matches UPPER, and dashed/underscored partials expand.
zstyle ':completion:*' matcher-list \
       'm:{a-zA-Z}={A-Za-z}' \
       'r:|[._-]=* r:|=*' \
       'l:|=* r:|=*'

# ── Use LS_COLORS for file/dir completion coloring ─────────────────
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── Cache completion results (speeds up slow completers e.g. aws) ──
zstyle ':completion:*' use-cache on
zstyle ':completion:*:complete:*' cache-path "$ZSH_CACHE_DIR/zcompcache"

# ── Process-name completion for kill/htop etc. ─────────────────────
zstyle ':completion:*:*:kill:*:processes' \
       list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,cmd'

# ── Don't suggest the cwd-equivalent (../current) ──────────────────
zstyle ':completion:*' ignore-parents parent pwd

# ── SSH/SCP host completion from known_hosts ───────────────────────
zstyle ':completion:*:(ssh|scp|sftp):*' hosts \
       ${${${(f)"$(cat ~/.ssh/known_hosts(N) 2>/dev/null)"}%%[# ]*}//,/ }
