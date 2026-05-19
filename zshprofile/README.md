# zshprofile

A fast, modular, and portable Zsh environment. Built on Oh My Zsh with
the Spaceship prompt, modern CLI replacements, and first-class workflow
support for Git, Docker, Kubernetes, and AWS.

Part of [el-amin-dev/dotfiles](https://github.com/el-amin-dev/dotfiles).

---

## Highlights

- **Modular** — one root `.zshrc` loader sources numbered modules; each
  module owns a single concern.
- **Fast** — lean prompt order, cached completions, minimal init hooks,
  async prompt rendering. Startup stays low even with a full toolchain.
- **Clean `$HOME`** — Oh My Zsh, plugins, history, and completion cache
  all live *inside this repository*. The only `$HOME` footprint is the
  `~/.zshrc` symlink.
- **Portable** — clone, run `install.sh`, get an identical shell on any
  machine. Third-party code is cloned, never committed.
- **Safe** — guarded destructive commands, no-clobber redirection, and
  clear visual failure indicators.

---

## Architecture

The root `.zshrc` is a loader only. It sources every module in
`modules/` in numeric order, then applies machine-specific overrides:

```
.zshrc                    Root loader (symlinked to ~/.zshrc)
│
├── modules/              Hand-written configuration, ordered
│   ├── 00-env.zsh        Environment, PATH, repo-local paths
│   ├── 10-omz.zsh        Oh My Zsh + Spaceship + plugin list
│   ├── 20-options.zsh    setopt — shell behavior
│   ├── 30-history.zsh    History configuration
│   ├── 40-completion.zsh Completion tuning
│   ├── 50-keybindings.zsh Key bindings
│   ├── 60-aliases.zsh    Unified aliases
│   ├── 70-functions.zsh  Custom functions (fzf pickers, helpers)
│   ├── 80-tools.zsh      External tool init (zoxide, fzf)
│   └── 90-spaceship.zsh  Prompt configuration
│
├── external/             Cloned code — GIT IGNORED
│   ├── oh-my-zsh/         Oh My Zsh (not ~/.oh-my-zsh)
│   └── plugins/           zsh-autosuggestions, zsh-syntax-highlighting
│
├── local/                Machine-specific overrides — GIT IGNORED
├── cache/                 History + compdump — GIT IGNORED
├── install.sh             Idempotent bootstrap
└── .gitignore
```

**Load order rationale:** dependencies load before dependents.
Environment first, then the framework and plugins, then shell behavior
(options, history, completion, keys), then conveniences (aliases,
functions), then external tool hooks, and finally the prompt and any
local overrides — which load last so they always win.

---

## Requirements

- Ubuntu / Debian-based Linux (uses `apt`)
- A terminal capable of using a Nerd Font

The installer provisions everything else, including the toolchain and a
Nerd Font.

---

## Installation

```bash
mkdir -p ~/projects
git clone https://github.com/el-amin-dev/dotfiles.git ~/projects/dotfiles
cd ~/projects/dotfiles/zshprofile
chmod +x install.sh
./install.sh
```

The installer is **idempotent** — re-running it only performs missing
steps. It will:

1. Install the CLI toolchain via `apt`
   (`zsh fzf zoxide eza bat ripgrep fd-find btop tmux`).
2. Clone Oh My Zsh into `external/oh-my-zsh/`.
3. Clone the Spaceship theme into Oh My Zsh's custom themes.
4. Clone `zsh-autosuggestions` and `zsh-syntax-highlighting`.
5. Install **FiraCode Nerd Font** to `~/.local/share/fonts/`.
6. Symlink `~/.zshrc` to this repository (backing up any existing file
   to `~/.zshrc.pre-dotfiles`).
7. Set Zsh as the default shell.

### Final manual step

Set your terminal's font to **FiraCode Nerd Font** in its preferences.
This cannot be scripted reliably and is required for prompt symbols to
render correctly.

Then open a new terminal, or run `exec zsh`.

---

## What's included

### Tooling

| Tool | Role |
|------|------|
| `fzf` | Fuzzy finder — history, files, custom pickers |
| `zoxide` | Frecency-based directory jumping (`cd`) |
| `eza` | Modern `ls` with Git awareness and tree view |
| `bat` | Syntax-highlighted `cat` and man pager |
| `ripgrep` | Fast `grep` |
| `fd` | Fast `find` (Ubuntu: `fdfind`) |
| `btop` | Resource monitor |
| `tmux` | Terminal multiplexer |

### Workflow integrations

- **Git** — concise aliases plus fuzzy branch/commit pickers.
- **Docker / Compose** — aliases and fuzzy container shell/log pickers.
- **Kubernetes** — `kubectl` aliases and a fuzzy pod-exec picker.
- **AWS** — profile helpers and completion (AWS only by design).
- **FastAPI / SvelteKit** — dev-server aliases, `.env` loader, venv
  helpers; the prompt surfaces Python/Node context per directory.

### Prompt

Spaceship, configured with a **lean section order** containing only the
relevant stack (directory, Git, Node, Python, Docker, Kubernetes, AWS,
virtualenv, execution time, exit code). Unlisted sections are never
loaded — the primary prompt-speed lever. Rendering is asynchronous, so
Git status never blocks input.

---

## Customization

- **Add or reorder behavior:** create or rename a file in `modules/`.
  The loader picks it up by numeric prefix automatically — the root
  `.zshrc` never needs editing.
- **Machine-specific settings:** put them in `local/local.zsh`. It is
  git-ignored and loaded last, so it overrides everything.
- **Edit the config quickly:** the `zshrc` alias opens this repository
  in `$EDITOR`.

---

## Performance

This setup is built to stay fast:

- Lean Spaceship prompt order — only used sections are loaded.
- Completion results cached (notably for `aws`/`kubectl`).
- A single external init subprocess (`zoxide`); `fzf` integration is
  de-duplicated against the Oh My Zsh plugin.
- Asynchronous prompt rendering.

To profile startup, add `zmodload zsh/zprof` to the top of `.zshrc`,
open a shell, and run `zprof`.

---

## License

MIT. See the repository [LICENSE](../LICENSE).
