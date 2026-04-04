# Vendored Build Assets

## Purpose

This branch keeps build-time release assets, editor defaults, Zsh plugin sources, and Claude skills under `vendor/` so local image builds stay fast and predictable.

- No GitHub release download is required for `antidote`, `btop`, `neovim`, `zellij`, or `yazi`
- No runtime `git clone` is required to ship the default LazyVim starter config
- No plugin repository clone is required for the default Zsh setup
- The image can ship vendored Claude skills without runtime network fetches
- Users do not need Git submodules or `git clone --recursive`

The machine-readable inventory lives in [`vendor/manifest.lock.json`](../vendor/manifest.lock.json).

## Directory Layout

```text
vendor/
├── claude/
│   └── skills/
│       ├── oh-my-claudepod/
│       └── superpowers/
├── manifest.lock.json
├── nvim/
│   └── lazyvim-starter/
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

The default shell setup sources these local copies directly from `/opt/vendor/zsh` inside the image.

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

## Vendored Claude Assets

### Claude runtime

This branch does not vendor the Claude Code binary itself. Docker and bootstrap install a pinned Claude Code native binary directly from Anthropic's official release bucket:

- `https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/`

The repo then wraps the installed binary with `claudepod-sync-config` and the `claude` launcher so `.env`-driven settings can be materialized into `~/.claude/settings.json` without replacing the rest of the user's Claude preferences.

### Claude skills

| Component | Version | Local path | Upstream source |
|-----------|---------|------------|-----------------|
| superpowers skills snapshot | `v5.0.7` | `vendor/claude/skills/superpowers/` | `obra/superpowers` tag archive |
| repo-managed Claude skills | repo-local | `vendor/claude/skills/oh-my-claudepod/` | maintained in this repository |

Only the upstream `skills/` tree is vendored on `dev/claude`. OpenCode-specific plugin wrappers are intentionally removed from this branch.

The image exposes the Claude skills root through:

- `/root/.claude/skills -> /opt/vendor/claude/skills`

Bootstrap installs the same skills tree into:

- `~/.claude/skills -> <prefix>/vendor/claude/skills`

## Update Workflow

Use the helper script below whenever you want to refresh the vendored assets:

```bash
bash build/update-vendor-assets.sh
```

After running it:

1. Review the new files under `vendor/`
2. Update [`vendor/manifest.lock.json`](../vendor/manifest.lock.json) if versions, commits, or Claude skill refs changed
3. Rebuild the image with `docker compose up -d --build`
4. Verify the container starts cleanly, the vendored Zsh plugins still load, Claude can resolve the vendored skills root, and `nvim` starts with the managed LazyVim starter

## Notes

- This approach intentionally avoids Git submodules.
- Local builds still need access to base image registries such as Docker Hub and GHCR.
- The default LazyVim config is vendored, but first-run plugin installation still needs network access.
- The vendored assets are part of the repository history, so version bumps should stay deliberate and infrequent.
