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
# (OMZ 'extract' plugin also exists; this is a self-contained backup.)
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
ports() { sudo lsof -i -P -n | rg LISTEN 2>/dev/null || sudo ss -tulpn; }

# ── srv: instant static HTTP server in cwd (FastAPI/Svelte testing) ─
srv() { local p="${1:-8000}"; print "serving $PWD on :$p"; python3 -m http.server "$p"; }

# ════════════════════════════════════════════════════════════════════
#  fzf-powered pickers — the big productivity wins
#  All guarded: no fzf → function still defined but warns cleanly.
# ════════════════════════════════════════════════════════════════════
_need_fzf() { (( $+commands[fzf] )) || { print "fzf not installed"; return 1; }; }

# ── fcd: fuzzy-cd into any subdirectory (bat-less, dir preview) ────
fcd() {
  _need_fzf || return
  local dir
  dir=$(fd --type d --hidden --exclude .git 2>/dev/null \
        | fzf --preview 'eza --tree --level=1 --color=always {} 2>/dev/null') \
        && cd -- "$dir"
}

# ── fe: fuzzy-find a file and open in $EDITOR (bat preview) ─────────
fe() {
  _need_fzf || return
  local file
  file=$(fd --type f --hidden --exclude .git 2>/dev/null \
        | fzf --preview 'bat --style=numbers --color=always --line-range :200 {} 2>/dev/null') \
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
        | fzf --ansi --preview 'git show --color=always {1} | bat --color=always 2>/dev/null' \
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
