# Vendored Build Assets

## Purpose

This project keeps build-time release assets, editor defaults, Zsh plugin sources, and OpenCode extensions under `vendor/` so local image builds stay fast and predictable.

- No GitHub release download is required for `antidote`, `btop`, `neovim`, `zellij`, or `yazi`
- No runtime `git clone` is required to ship the default LazyVim starter config
- No plugin repository clone is required for the default Zsh setup
- The image can ship vendored OpenCode plugins and global skills without runtime network fetches
- Users do not need Git submodules or `git clone --recursive`

The machine-readable inventory lives in [`vendor/manifest.lock.json`](../vendor/manifest.lock.json).

## Directory Layout

```text
vendor/
├── manifest.lock.json
├── nvim/
│   └── lazyvim-starter/
├── opencode/
│   ├── packages/
│   │   └── superpowers/
│   │       ├── .opencode/
│   │       │   └── plugins/
│   │       │       └── superpowers.js
│   │       ├── package.json
│   │       └── skills/
│   └── skills/
├── releases/
│   ├── antidote/
│   ├── btop/
│   ├── neovim/
│   ├── yazi/
│   └── zellij/
└── zsh/
    ├── ohmyzsh/
    ├── powerlevel10k/
    ├── zsh-autosuggestions/
    ├── zsh-history-substring-search/
    └── zsh-syntax-highlighting/
```

## Vendored Release Assets

| Component | Version | Local path | Upstream source |
|-----------|---------|------------|-----------------|
| Antidote | `v2.0.10` | `vendor/releases/antidote/v2.0.10/` | `mattmc3/antidote` tag archive |
| btop | `v1.4.6` | `vendor/releases/btop/v1.4.6/` | `aristocratos/btop` release assets |
| Neovim | `v0.12.0` | `vendor/releases/neovim/v0.12.0/` | `neovim/neovim` release assets |
| Zellij | `v0.44.0` | `vendor/releases/zellij/v0.44.0/` | `zellij-org/zellij` release assets |
| Yazi | `v26.1.22` | `vendor/releases/yazi/v26.1.22/` | `sxyazi/yazi` Debian packages |

Each release directory includes a `SHA256SUMS` file. The `build/install-*.sh` scripts verify the local asset before extracting or installing it.

## Vendored Zsh Plugins

| Component | Source | Local path |
|-----------|--------|------------|
| oh-my-zsh | `ohmyzsh/ohmyzsh@9e2c1548c3dfeefd055e1c6606f66657093ae928` | `vendor/zsh/ohmyzsh/` |
| Powerlevel10k | `romkatv/powerlevel10k@604f19a9eaa18e76db2e60b8d446d5f879065f90` | `vendor/zsh/powerlevel10k/` |
| zsh-autosuggestions | `zsh-users/zsh-autosuggestions@85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5` | `vendor/zsh/zsh-autosuggestions/` |
| zsh-history-substring-search | `zsh-users/zsh-history-substring-search@14c8d2e0ffaee98f2df9850b19944f32546fdea5` | `vendor/zsh/zsh-history-substring-search/` |
| zsh-syntax-highlighting | `zsh-users/zsh-syntax-highlighting@1d85c692615a25fe2293bdd44b34c217d5d2bf04` | `vendor/zsh/zsh-syntax-highlighting/` |

The default shell setup now sources these local copies directly from `/opt/vendor/zsh` inside the image.

## Vendored Neovim Defaults

| Component | Source | Local path |
|-----------|--------|------------|
| LazyVim starter | `LazyVim/starter@803bc181d7c0d6d5eeba9274d9be49b287294d99` | `vendor/nvim/lazyvim-starter/` |

`LazyVim/starter` is vendored as a pinned source snapshot instead of a release package because the upstream repository does not publish installable release artifacts.

That split is intentional:

- `neovim` itself comes from official release tarballs under `vendor/releases/neovim/`
- the default editor config comes from `vendor/nvim/lazyvim-starter/`
- the vendored starter includes `.openpod-source-commit` so installer metadata can record the pinned source commit

The Docker image and bootstrap flow both install this starter as the default managed `nvim` config. First `nvim` launch still bootstraps `lazy.nvim` and the rest of the plugin set from upstream.

## Vendored OpenCode Assets

### Plugin packages

| Component | Version | Local path | Upstream source |
|-----------|---------|------------|-----------------|
| superpowers | `v5.0.7` | `vendor/opencode/packages/superpowers/` | `obra/superpowers` tag archive |

`superpowers` is vendored as a full package snapshot, not as a copied `SKILL.md` bundle.

That layout is intentional:

- the plugin entrypoint stays at `vendor/opencode/packages/superpowers/.opencode/plugins/superpowers.js`
- the bundled skills stay at `vendor/opencode/packages/superpowers/skills/`
- the package root survives intact after `COPY vendor /opt/vendor`

This matters because the upstream plugin resolves `../../skills` relative to its own entrypoint and appends that directory to `config.skills.paths`. Flattening only the JS file into another directory would break that behavior.

The image creates `/root/.config/opencode/plugins/superpowers.js` as a symlink to the vendored package entrypoint, while the package content itself remains under `/opt/vendor/opencode/packages/superpowers`.

### Global skills

`vendor/opencode/skills/` is reserved for repository-maintained OpenCode global skills.

Unlike plugin package snapshots, this directory is intentionally kept outside the destructive refresh logic in `build/update-vendor-assets.sh`, so future repo-maintained skills are not deleted when vendored upstream assets are refreshed.

## Update Workflow

Use the helper script below whenever you want to refresh the vendored assets:

```bash
bash build/update-vendor-assets.sh
```

After running it:

1. Review the new files under `vendor/`
2. Update [`vendor/manifest.lock.json`](../vendor/manifest.lock.json) if versions, commits, or OpenCode package refs changed
3. Rebuild the image with `docker compose up -d --build`
4. Verify the container starts cleanly, the vendored Zsh plugins still load, OpenCode can see the vendored plugin/skill roots, and `nvim` starts with the managed LazyVim starter

## Notes

- This approach intentionally avoids Git submodules.
- Local builds still need access to base image registries such as Docker Hub and GHCR.
- The default LazyVim config is vendored, but first-run plugin installation still needs network access.
- Vendored OpenCode plugin packages should keep their upstream package-root layout unless their runtime behavior is re-validated.
- The vendored assets are part of the repository history, so version bumps should stay deliberate and infrequent.
