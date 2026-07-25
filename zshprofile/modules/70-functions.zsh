# ════════════════════════════════════════════════════════════════════
#  70-functions — custom shell mini-programs
#  Zero startup cost: functions are PARSED here, not run.
#  fzf-based pickers depend on fzf (guarded). bat used for previews.
# ════════════════════════════════════════════════════════════════════

# ── mkcd: make a dir (and parents) then cd into it ─────────────────
mkcd() {
  [[ -z "$1" ]] && { print "usage: mkcd <dir>"; return 1; }
  mkdir -p -- "$1" && cd -- "$1"
}

# ── extract: unpack almost any archive by extension ────────────────
# Defined ONLY as a fallback. The Oh My Zsh `extract` plugin is loaded in
# 10-omz.zsh and handles far more formats, and it extracts into a
# subdirectory rather than spraying files into $PWD. Because this module
# loads at 70, an unconditional definition here would silently replace
# the better implementation with this weaker one — which is what it was
# doing. The guard keeps this as a genuine backup for a machine where the
# plugin is unavailable.
if (( ! $+functions[extract] )); then
extract() {
  [[ -f "$1" ]] || { print "extract: '$1' is not a file"; return 1; }
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1"   ;;
    *.tar.gz|*.tgz)   tar xzf "$1"   ;;
    *.tar.xz)         tar xJf "$1"   ;;
    *.tar)            tar xf  "$1"   ;;
    *.bz2)            bunzip2 "$1"   ;;
    *.gz)             gunzip  "$1"   ;;
    *.zip)            unzip   "$1"   ;;
    *.rar)            unrar x "$1"   ;;
    *.7z)             7z x    "$1"   ;;
    *) print "extract: don't know how to handle '$1'"; return 1 ;;
  esac
}
fi

# ── keytest: print the raw escape sequence of a key ────────────────
# Promised in 50-keybindings. Run it, press a key, get the code to bind.
keytest() {
  print "Press a key (Ctrl-C to stop). Bind the shown sequence in 50-keybindings.zsh:"
  cat -v
}

# ── mkbak: timestamped backup of a file ────────────────────────────
mkbak() {
  [[ -f "$1" ]] || { print "mkbak: '$1' not found"; return 1; }
  cp -- "$1" "$1.$(date +%Y%m%d-%H%M%S).bak" && print "backed up → $1.<ts>.bak"
}

# ── ports: what's listening, readable ──────────────────────────────
# ss is tried first: it is part of iproute2 and present on every modern
# Linux, whereas lsof frequently is not. rg is only used when installed,
# so this does not become another undeclared dependency.
ports() {
  if (( $+commands[ss] )); then
    sudo ss -tulpn
  elif (( $+commands[lsof] )); then
    if (( $+commands[rg] )); then
      sudo lsof -i -P -n | rg LISTEN
    else
      sudo lsof -i -P -n | grep LISTEN
    fi
  else
    print "ports: neither ss nor lsof is installed"; return 1
  fi
}

# ── srv: instant static HTTP server in cwd (FastAPI/Svelte testing) ─
srv() { local p="${1:-8000}"; print "serving $PWD on :$p"; python3 -m http.server "$p"; }

# ════════════════════════════════════════════════════════════════════
#  fzf-powered pickers — the big productivity wins
#  All guarded: no fzf → function still defined but warns cleanly.
# ════════════════════════════════════════════════════════════════════
_need_fzf() { (( $+commands[fzf] )) || { print "fzf not installed"; return 1; }; }
_need_fd()  { [[ -n "$ZSH_FD_BIN" ]] || { print "fd not installed"; return 1; }; }

# ── Preview commands for the pickers below ─────────────────────────
# These strings are handed to fzf, which runs them through `sh`. That
# shell has none of this config's aliases, so a literal `bat` here is
# broken on Debian and Ubuntu where the binary is `batcat` — the preview
# pane just renders empty, with no error to explain why. $ZSH_BAT_BIN
# holds the name that actually exists (00-env.zsh, ADR-003).
#
# Built once at load rather than inline, so every picker previews
# identically and there is a single place to change it.
if [[ -n "$ZSH_BAT_BIN" ]]; then
  _fzf_file_preview="$ZSH_BAT_BIN --style=numbers --color=always --line-range :200 {}"
  _fzf_pipe_preview="$ZSH_BAT_BIN --color=always"
else
  # No bat: cat still previews the file, just without syntax colour.
  _fzf_file_preview='cat {}'
  _fzf_pipe_preview='cat'
fi

# ── fcd: fuzzy-cd into any subdirectory (directory-tree preview) ───
fcd() {
  _need_fzf || return; _need_fd || return
  local dir
  dir=$("$ZSH_FD_BIN" --type d --hidden --exclude .git 2>/dev/null \
        | fzf --preview 'eza --tree --level=1 --color=always {} 2>/dev/null') \
        && cd -- "$dir"
}

# ── fe: fuzzy-find a file and open in $EDITOR (bat preview) ─────────
fe() {
  _need_fzf || return; _need_fd || return
  local file
  file=$("$ZSH_FD_BIN" --type f --hidden --exclude .git 2>/dev/null \
        | fzf --preview "$_fzf_file_preview") \
        && ${EDITOR:-vim} "$file"
}

# ── fkill: pick a process and kill it ──────────────────────────────
fkill() {
  _need_fzf || return
  local pid
  pid=$(ps -ef | sed 1d | fzf -m --header='[kill:select process]' | awk '{print $2}')
  [[ -n "$pid" ]] && print "$pid" | xargs kill -"${1:-15}" && print "killed $pid"
}

# ── fgb: fuzzy git branch switch (local + remote, bat log preview) ─
fgb() {
  _need_fzf || return
  git rev-parse --is-inside-work-tree &>/dev/null || { print "not a git repo"; return 1; }
  local br
  br=$(git branch -a --color=always | rg -v '/HEAD\s' | sed 's/^..//' \
       | fzf --ansi --preview 'git log --oneline --graph --color=always {1} 2>/dev/null | head -50') \
       && git switch "$(print "$br" | sed 's#remotes/[^/]*/##' | awk '{print $1}')"
}

# ── fco: fuzzy checkout any commit (browse history, bat preview) ───
fco() {
  _need_fzf || return
  git rev-parse --is-inside-work-tree &>/dev/null || { print "not a git repo"; return 1; }
  local commit
  commit=$(git log --oneline --color=always \
        | fzf --ansi --preview "git show --color=always {1} | $_fzf_pipe_preview 2>/dev/null" \
        | awk '{print $1}') \
        && git checkout "$commit"
}

# ── dsh: fuzzy-pick a running container and shell into it ──────────
dsh() {
  _need_fzf || return
  local c
  c=$(docker ps --format '{{.Names}}' | fzf --header='[docker exec]') \
     && docker exec -it "$c" "${1:-sh}"
}

# ── dlogf: fuzzy-pick a container and follow its logs ──────────────
dlogf() {
  _need_fzf || return
  local c
  c=$(docker ps --format '{{.Names}}' | fzf --header='[docker logs]') \
     && docker logs -f --tail 200 "$c"
}

# ── kpod: fuzzy-pick a k8s pod and exec into it ────────────────────
kpod() {
  _need_fzf || return
  local pod
  pod=$(kubectl get pods --no-headers -o custom-columns=':metadata.name' 2>/dev/null \
        | fzf --header='[kubectl exec]') \
        && kubectl exec -it "$pod" -- "${1:-sh}"
}

# ── envup: load a .env file into the current shell ─────────────────
envup() {
  local f="${1:-.env}"
  [[ -f "$f" ]] || { print "envup: '$f' not found"; return 1; }
  set -a; source "$f"; set +a
  print "loaded $f into environment"
}
