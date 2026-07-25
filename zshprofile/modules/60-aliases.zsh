# ════════════════════════════════════════════════════════════════════
#  60-aliases — short names for frequent commands.
#
#  Two rules govern this file:
#
#  1. GUARDED — an alias for a modern tool is only defined if that tool
#     is actually installed. A missing tool degrades to the standard
#     command instead of producing "command not found".
#
#  2. NO SHADOWING OF STANDARD TOOLS — `cat`, `grep`, `ls`, `find` and
#     friends keep their standard behaviour and their standard flags.
#     Modern replacements are reached by their own names. Rebinding a
#     POSIX tool to a look-alike with different flags and different
#     defaults is the single largest source of "why did that not work"
#     in a shared shell config; see docs/DECISIONS.md (ADR-002).
#     `ls` is the one deliberate exception, explained inline below.
#
#  Zero startup cost: aliases are pure in-memory assignments.
# ════════════════════════════════════════════════════════════════════

# ── Debian/Ubuntu binary-name fixes ────────────────────────────────
# Debian and Ubuntu ship fd as `fdfind` and bat as `batcat` because of
# unrelated name clashes. Alias the upstream names so the rest of this
# config (and $FZF_DEFAULT_COMMAND) can just say `fd` and `bat`.
(( $+commands[fdfind] )) && alias fd='fdfind'

# ── bat: a syntax-highlighting file viewer ─────────────────────────
# `bat` is plain by default (see config/bat.conf): syntax colour only,
# no line numbers, no gutter, no header — so terminal output can be
# selected and copied without dragging decorations along with it.
#
#   bat  <file>   colour, copy-paste-safe                (the default)
#   batn <file>   line numbers + git change gutter + header
#   batp <file>   same as bat, but paged
#
# Resolve the real binary name ONCE and build every alias on it, so the
# aliases are correct whether the binary is `bat` or `batcat`.
if (( $+commands[batcat] )); then
  alias bat='batcat'
  alias batn='batcat --style=numbers,changes,header'
  alias batp='batcat --paging=always'
elif (( $+commands[bat] )); then
  alias batn='bat --style=numbers,changes,header'
  alias batp='bat --paging=always'
fi
# NOTE: `cat` is intentionally NOT aliased to bat. Doing so breaks
# `cat -v`, `cat -A`, `cat -n`, `cat -s`, `cat -e`, reading from stdin,
# and every pasted script that relies on cat behaving like cat.

# ── eza: modern ls — git-aware, tree-capable ───────────────────────
# `ls` IS aliased here, as the one deliberate exception to the
# no-shadowing rule: eza accepts the flags people actually type
# interactively (-l, -a, -h) and its output is only ever read by a
# human, never parsed. Long/scripted forms remain available as `\ls`
# or `command ls`. No icons: listings stay plain, just coloured and
# git-aware. Add --icons=auto below to enable them.
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first'
  alias l='eza -lbF --git --group-directories-first'
  alias ll='eza -lbGF --git --header --group-directories-first'
  alias la='eza -lbhHigUmuSa --git --color-scale'
  alias lt='eza --tree --level=2'
  alias ltt='eza --tree --level=4'
else
  alias l='ls -lh'
  alias ll='ls -lh'
  alias la='ls -lAh'
  alias lt='ls -R'
fi

# ── ripgrep — reached by its own name, never as `grep` ─────────────
# rg is not a drop-in grep: it recurses by default, silently skips
# .gitignore'd and hidden files, and uses a different regex dialect.
# Aliasing grep→rg makes a familiar command return fewer results with
# no error, which is the worst possible failure mode.
#
#   rg   <pat>    fast search, respects .gitignore     (the default)
#   rga  <pat>    search EVERYTHING — hidden + ignored files too
#   rgf  <pat>    match against file NAMES rather than contents
if (( $+commands[rg] )); then
  alias rga='rg --hidden --no-ignore'
  alias rgf='rg --files | rg'
fi

# ── grep: keep the colour, drop the silent exclusions ──────────────
# Oh My Zsh (lib/grep.zsh, sourced by module 10) aliases grep to:
#
#   grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv}
#
# The --color half is additive and welcome. The --exclude-dir half is
# the exact failure mode ADR-002 exists to prevent: `grep -r` quietly
# returns fewer results, with no error and no indication that entire
# directories were skipped. Searching .venv for which package pulls in
# a symbol, or .git for a lost commit message, silently finds nothing.
#
# Redefined here rather than unaliased, so the colour survives. This
# must stay AFTER module 10, which is where the OMZ alias is defined.
# egrep/fgrep get the same treatment; OMZ points both at its own
# aliased grep, so they inherit the exclusions too.
alias grep='grep --color=auto'
alias egrep='grep --color=auto -E'
alias fgrep='grep --color=auto -F'

# ── Directory navigation ───────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'                         # `-` alone → previous directory

# ── zoxide: frecency directory jumping ─────────────────────────────
# `cd` is left alone — it stays the shell builtin, so it either goes
# where you said or fails. Jumping is opt-in via z / zi / j.
# Initialised in modules/95-zoxide.zsh (must load last).
#   z  <keyword>   jump to the best-matching known directory
#   zi <keyword>   pick interactively from the matches
(( $+commands[zoxide] )) && alias j='z'

# ── Git (concise set; the OMZ git plugin adds many more) ───────────
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit -v'
alias gcm='git commit -m'
alias gca='git commit --amend --no-edit'
alias gco='git checkout'
alias gsw='git switch'
alias gb='git branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all'
alias gp='git push'
alias gpf='git push --force-with-lease'    # refuses to clobber others' work
alias gpl='git pull --rebase --autostash'
alias gst='git stash'
alias gstp='git stash pop'
alias grh='git reset --hard'
alias gclean='git clean -fd'

# ── GitHub CLI ─────────────────────────────────────────────────────
alias ghpr='gh pr create --fill'
alias ghprv='gh pr view --web'
alias ghrun='gh run list --limit 10'
alias ghwatch='gh run watch'

# ── Docker / Compose ───────────────────────────────────────────────
alias d='docker'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f --tail 100'
alias dprune='docker system prune -af --volumes'   # destructive: prunes volumes
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f --tail 100'
alias dcr='docker compose restart'
alias dcb='docker compose build'

# ── Kubernetes ─────────────────────────────────────────────────────
alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pods -o wide'
alias kgs='kubectl get svc'
alias kgd='kubectl get deploy'
alias kd='kubectl describe'
alias kl='kubectl logs -f --tail=100'
alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kctx='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'

# ── AWS ────────────────────────────────────────────────────────────
alias awswho='aws sts get-caller-identity'
alias awsp='export AWS_PROFILE'            # usage: awsp <profile-name>
alias awsls='aws s3 ls'

# ── Python ─────────────────────────────────────────────────────────
alias py='python3'
alias venv='python3 -m venv .venv && source .venv/bin/activate'
alias act='source .venv/bin/activate'
alias fapi='uvicorn app.main:app --reload'

# ── Node / npm ─────────────────────────────────────────────────────
# Namespaced on purpose: bare `dev`, `build` and `serve` are real
# binaries in several toolchains, and shadowing them breaks those tools
# in ways that are very hard to diagnose.
alias nr='npm run'
alias nrd='npm run dev'
alias nrb='npm run build'
alias nrp='npm run preview'

# ── System ─────────────────────────────────────────────────────────
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias path='print -l $path'                # one PATH entry per line
alias reload='exec zsh'                    # restart the shell cleanly
alias zshconf='${EDITOR:-vim} "$ZSH_PROFILE_DIR"'   # open this config repo
alias zshrc='zshconf'                      # kept for muscle memory
(( $+commands[btop] )) && alias top='btop'

# ── Guarded destructive commands ───────────────────────────────────
# These DO shadow standard tools, which the no-shadowing rule allows
# only here: the flags are additive prompts, no behaviour is removed,
# and the standard form is one backslash away (`\rm`, `command rm`).
#   rm -I  → one prompt when deleting >3 files or recursing
#   cp/mv -i → prompt before overwriting an existing file
alias rm='rm -I'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -pv'
