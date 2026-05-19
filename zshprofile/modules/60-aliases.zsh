# ════════════════════════════════════════════════════════════════════
#  60-aliases — short names for frequent commands
#  Guarded: if a modern tool is missing, we DON'T alias (no breakage).
#  Zero startup cost. Order: core fixes → nav → modern CLI → git →
#  docker → k8s → aws → safety.
# ════════════════════════════════════════════════════════════════════

# ── Ubuntu naming fixes (the issue flagged in 00-env) ──────────────
# Debian/Ubuntu ship these binaries under different names.
(( $+commands[fdfind] )) && alias fd='fdfind'
(( $+commands[batcat] )) && alias bat='batcat'
# After this, $FZF_DEFAULT_COMMAND='fd …' and your 'bat' habit both work.

# ── eza: modern ls (git-aware, tree). NO icons (plain, as requested) ─
# Icons removed deliberately: no Nerd Font folder/music/picture glyphs
# in listings — output stays plain like classic ls, just colored and
# git-aware. Re-add --icons=auto here if you ever want them back.
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first'
  alias l='eza -lbF --git --group-directories-first'
  alias ll='eza -lbGF --git --header --group-directories-first'
  alias la='eza -lbhHigUmuSa --git --color-scale'
  alias lt='eza --tree --level=2'
  alias ltt='eza --tree --level=4'
else
  alias ll='ls -lh'
  alias la='ls -lAh'
fi

# ── bat: cat replacement. ALL behavior lives in config/bat.conf ────
# (no-pager default, git +/~ change gutter, line numbers, header).
# Aliases only map names now — no flags here, so cat / catt / and the
# bat previews in fe/fco/fcd are guaranteed identical. That single
# source of truth is the whole point of the bat.conf approach.
if (( $+commands[bat] )) || (( $+commands[batcat] )); then
  alias cat='bat'                       # colored, no-pager (per bat.conf)
  alias catt='bat --paging=always'      # opt-in paged view when wanted
  # raw, unstyled cat still available as \cat  or  command cat
fi

# ── ripgrep / fd nav ───────────────────────────────────────────────
(( $+commands[rg] )) && alias grep='rg'
alias rgf='rg --files | rg'             # find files by name fast
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'                       # '-' → previous dir

# ── zoxide: smarter cd (j = jump). Init is in 80-tools. ────────────
# 'z foo' jumps to best match; 'zi' interactive. Alias kept short:
(( $+commands[zoxide] )) && alias j='z'

# ── Git (concise; OMZ git plugin adds many more) ───────────────────
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
alias gpf='git push --force-with-lease'   # safer than --force
alias gpl='git pull --rebase --autostash'
alias gst='git stash'
alias gstp='git stash pop'
alias grh='git reset --hard'
alias gclean='git clean -fd'

# ── GitHub CLI ─────────────────────────────────────────────────────
alias ghpr='gh pr create --fill'
alias ghprv='gh pr view --web'
alias ghrun='gh run list --limit 10'      # GitHub Actions runs
alias ghwatch='gh run watch'

# ── Docker / Compose ───────────────────────────────────────────────
alias d='docker'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f --tail 100'
alias dprune='docker system prune -af --volumes'
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

# ── AWS (you use AWS only) ─────────────────────────────────────────
alias awswho='aws sts get-caller-identity'
alias awsp='export AWS_PROFILE'           # usage: awsp myprofile
alias awsls='aws s3 ls'

# ── FastAPI / Python dev ───────────────────────────────────────────
alias fapi='uvicorn app.main:app --reload'
alias py='python3'
alias venv='python3 -m venv .venv && source .venv/bin/activate'
alias act='source .venv/bin/activate'

# ── SvelteKit / Node dev ───────────────────────────────────────────
alias dev='npm run dev'
alias build='npm run build'
alias prev='npm run preview'

# ── System / safety (your "safer commands" goal) ───────────────────
alias rm='rm -I --preserve-root'          # prompt if removing >3 or recursive
alias cp='cp -i'                          # prompt before overwrite
alias mv='mv -i'                          # prompt before overwrite
alias mkdir='mkdir -pv'                   # make parents, be verbose
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias path='echo $PATH | tr ":" "\n"'     # readable PATH
alias reload='exec zsh'                    # reload shell cleanly
alias zshrc='$EDITOR $ZSH_PROFILE_DIR'     # jump to this config repo
(( $+commands[btop] )) && alias top='btop'
