# dotfiles

Personal development environment configuration — modular, portable, and
designed to keep `$HOME` clean.

> **Design principle:** every tool's config lives inside this repository.
> The only footprint in `$HOME` is a small number of symlinks. Cloned
> third-party code (frameworks, plugins) is git-ignored and reproduced
> by each module's `install.sh`.

---

## Repository layout

```
dotfiles/
└── zshprofile/      Zsh shell environment — see its dedicated README
```

> Additional configurations (tmux, vim, git, …) will be added as
> sibling directories, each self-contained with its own README and
> installer following the same conventions.

---

## Modules

| Module | Description | Documentation |
|--------|-------------|---------------|
| **zshprofile** | A fast, modular Zsh setup: Oh My Zsh + Spaceship prompt, modern CLI tooling (fzf, zoxide, eza, bat, ripgrep, fd), and workflow integrations for Git, Docker, Kubernetes, and AWS. | [zshprofile/README.md](zshprofile/README.md) |

---

## Quick start

Clone the repository:

```bash
mkdir -p ~/projects
git clone https://github.com/el-amin-dev/dotfiles.git ~/projects/dotfiles
```

Then follow the setup guide for the module you want. For the Zsh
environment:

```bash
cd ~/projects/dotfiles/zshprofile
chmod +x install.sh      # ensure the installer is executable
./install.sh
```

See **[zshprofile/README.md](zshprofile/README.md)** for full details,
architecture, and customization.

---

## Philosophy

- **Modular** — each concern is an independent, replaceable unit.
- **Portable** — clone anywhere, run one installer, identical result.
- **Clean `$HOME`** — configuration is referenced, never scattered.
- **Reproducible** — third-party code is fetched, never vendored.
- **Idempotent** — installers are safe to re-run.

---

## License

MIT — see [LICENSE](LICENSE). Use, fork, and adapt freely.
