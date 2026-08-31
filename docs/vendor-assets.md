# Vendored Build Assets

## Purpose

This repository keeps shared host-installer assets under `vendor/` so `omd` can install common shell and editor tooling from pinned snapshots where practical.

Shared vendored assets include:

- release archives for `antidote`, `atuin`, `btop`, `neovim`, `zellij`, `yazi`, and `witr`
- Zsh plugin snapshots
- the LazyVim starter snapshot

The machine-readable inventory lives in [`vendor/manifest.lock.json`](../vendor/manifest.lock.json).

## Vendor Layout

```text
vendor/
├── manifest.lock.json
├── nvim/
│   └── lazyvim-starter/
├── releases/
│   ├── antidote/
│   ├── atuin/
│   ├── btop/
│   ├── neovim/
│   ├── witr/
│   ├── yazi/
│   └── zellij/
└── zsh/
    ├── ohmyzsh/
    ├── powerlevel10k/
    ├── zsh-autosuggestions/
    ├── zsh-history-substring-search/
    └── zsh-syntax-highlighting/
```

## Shared Release Assets

| Component | Version source | Local path |
|-----------|----------------|------------|
| Antidote | `versions.env` | `vendor/releases/antidote/` |
| Atuin | `versions.env` | `vendor/releases/atuin/` |
| btop | `versions.env` | `vendor/releases/btop/` |
| Neovim | `versions.env` | `vendor/releases/neovim/` |
| Witr | `versions.env` | `vendor/releases/witr/` |
| Yazi | `versions.env` | `vendor/releases/yazi/` |
| Zellij | `versions.env` | `vendor/releases/zellij/` |

Each release directory includes a `SHA256SUMS` file. Shared install scripts in `build/` verify these local assets before extracting or installing them.

## Update Workflow

Use:

```bash
bash build/update-vendor-assets.sh
```

After running it:

1. Review changes under `vendor/releases/`.
2. Review changes under `vendor/zsh/`.
3. Review changes under `vendor/nvim/lazyvim-starter/`.
4. Update [`vendor/manifest.lock.json`](../vendor/manifest.lock.json) if versions or sources changed.
5. Run `bash tests/run.sh` and `cargo test -p omd`.

## Notes

- Shared assets stay in `vendor/`.
- Component install behavior belongs in `modules/` and reusable install helpers belong in `build/`.
- This project intentionally avoids Git submodules.
- Host installation still needs access to the selected package-manager mirrors for non-vendored formula operations.
- Gitee CLI is not vendored; its installer fetches the official release and requires a matching SHA256 entry before activation.
