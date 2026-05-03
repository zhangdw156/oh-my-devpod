# Vendored Build Assets

## Purpose

This repository keeps shared build-time assets under `vendor/` so the common `devpod` base stays reproducible across all runtime flavors.

Shared vendored assets include:

- release archives for `antidote`, `atuin`, `btop`, `neovim`, `zellij`, and `yazi`
- Zsh plugin snapshots
- the LazyVim starter snapshot

OpenCode-specific vendored assets are no longer shared. They now live under `runtime/openpod/vendor/opencode/` and are owned by the `openpod` flavor.

The machine-readable inventory lives in [`vendor/manifest.lock.json`](../vendor/manifest.lock.json).

## Shared Vendor Layout

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
│   ├── yazi/
│   └── zellij/
└── zsh/
    ├── ohmyzsh/
    ├── powerlevel10k/
    ├── zsh-autosuggestions/
    ├── zsh-history-substring-search/
    └── zsh-syntax-highlighting/
```

## Flavor-Owned Runtime Assets

Flavor-specific runtime assets live under `runtime/<flavor>/`.

The OpenCode flavor is the only flavor that owns vendored harness assets:

```text
runtime/openpod/
├── bin/
├── config/
│   └── opencode.json
├── install-harness.sh
├── skills/
└── vendor/
    └── opencode/
        ├── packages/
        │   └── superpowers/
        └── skills/
```

`runtime/claudepod/skills/superpowers/`, `runtime/codexpod/skills/superpowers/`, `runtime/copilotpod/skills/superpowers/`, and `runtime/geminipod/skills/superpowers/` are synchronized copies of the same upstream `superpowers` skills snapshot, but they are flavor-owned trees rather than shared vendor roots.

## Shared Release Assets

| Component | Version | Local path |
|-----------|---------|------------|
| Antidote | `v2.0.10` | `vendor/releases/antidote/v2.0.10/` |
| Atuin | `v18.15.2` | `vendor/releases/atuin/v18.15.2/` |
| btop | `v1.4.6` | `vendor/releases/btop/v1.4.6/` |
| Neovim | `v0.12.0` | `vendor/releases/neovim/v0.12.0/` |
| Zellij | `v0.44.0` | `vendor/releases/zellij/v0.44.0/` |
| Yazi | `v26.1.22` | `vendor/releases/yazi/v26.1.22/` |

Each release directory includes a `SHA256SUMS` file. The shared install scripts in `build/` verify these local assets before extracting or installing them.

## Flavor-Specific Skill Materialization

`build/update-vendor-assets.sh` refreshes the upstream `superpowers` package snapshot into:

- `runtime/openpod/vendor/opencode/packages/superpowers/`

It then synchronizes the bundled `skills/` subtree into:

- `runtime/claudepod/skills/superpowers/`
- `runtime/codexpod/skills/superpowers/`
- `runtime/copilotpod/skills/superpowers/`
- `runtime/geminipod/skills/superpowers/`

This keeps all five runtime flavors aligned to the same upstream `superpowers` snapshot while preserving the ownership boundary that OpenCode-specific vendored assets belong to `openpod`.

## Update Workflow

Use:

```bash
bash build/update-vendor-assets.sh
```

After running it:

1. Review changes under `vendor/`
2. Review changes under `runtime/openpod/vendor/opencode/`
3. Review synchronized flavor skills under `runtime/claudepod/skills/`, `runtime/codexpod/skills/`, `runtime/copilotpod/skills/`, and `runtime/geminipod/skills/`
4. Update [`vendor/manifest.lock.json`](../vendor/manifest.lock.json) if versions or sources changed
5. Rebuild the flavors:

```bash
docker build -f Dockerfile.devpod -t devpod:local .
docker build -f docker/openpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t openpod:local .
docker build -f docker/claudepod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t claudepod:local .
docker build -f docker/codexpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t codexpod:local .
docker build -f docker/copilotpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t copilotpod:local .
docker build -f docker/geminipod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t geminipod:local .
```

## Notes

- Shared assets stay in `vendor/`; harness-specific runtime assets stay in `runtime/<flavor>/`
- `runtime/openpod/vendor/opencode/skills/` stays outside the destructive package-refresh path so repo-maintained global OpenCode skills are preserved
- This project intentionally avoids Git submodules
- Local builds still need network access to base image registries and any harness installer endpoints that are not vendored
