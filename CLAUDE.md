# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

`oh-my-openpod` builds a Docker-based development container around Ubuntu 24.04. The image bundles OpenCode, uv, Git, Zsh, vendored shell plugins, vendored release assets, and vendored OpenCode extensions so the container can be used as a reproducible coding environment on local machines or servers.

## Core development commands

### Build and run the dev container

```bash
# Build the local image from the current repo state
docker compose build

# Build and start the container
docker compose up -d --build

# Start with a different mounted workspace
PROJECT_DIR=/path/to/project docker compose up -d --build

# Enter the running container
docker compose exec openpod zsh

# Run one-off commands in the image without keeping the container
docker compose run --rm openpod -lc 'opencode --help'
```

### Verify OpenCode wiring inside the container

```bash
# Inspect resolved OpenCode config
docker compose run --rm openpod -lc 'opencode debug config'

# List discovered skills
docker compose run --rm openpod -lc 'opencode debug skill'

# Show OpenCode config/data/cache paths
docker compose run --rm openpod -lc 'opencode debug paths'
```

### Refresh vendored assets

```bash
bash build/update-vendor-assets.sh
```

After refreshing vendored assets, rebuild the image and re-verify the container behavior.

### Superpowers plugin tests

The repository vendors the full `obra/superpowers` package, including its upstream OpenCode test scripts.

```bash
# Run the default plugin-structure test suite
bash vendor/opencode/packages/superpowers/tests/opencode/run-tests.sh

# Run one specific plugin test
bash vendor/opencode/packages/superpowers/tests/opencode/run-tests.sh --test test-plugin-loading.sh

# Run the plugin-loading test directly
bash vendor/opencode/packages/superpowers/tests/opencode/test-plugin-loading.sh

# Include upstream integration tests that require OpenCode
bash vendor/opencode/packages/superpowers/tests/opencode/run-tests.sh --integration
```

## Release and versioning

- The single source of truth for the image version is `docker-compose.yml` in the `image:` field.
- Development versions use `x.y.z.devN`.
- Release versions use `x.y.z`.
- `.github/workflows/publish-ghcr.yml` reads `docker-compose.yml` to decide what tag to publish.
- Pushes to `main` only publish to GHCR when the version is not a dev version.

Release flow is documented in `DEVELOPMENT.md`; follow that file when cutting a release branch or bumping to the next dev version.

## High-level architecture

### 1. Image assembly is driven by `Dockerfile` + vendored assets

The image is built from `ubuntu:24.04` and assembles its toolchain in layers:

- installs a small base package set with `apt`
- copies the entire `vendor/` tree into `/opt/vendor`
- copies the `opencode` binary from `ghcr.io/anomalyco/opencode`
- copies `uv` from `ghcr.io/astral-sh/uv`
- installs `btop`, `antidote`, `zellij`, and `yazi` from vendored release assets via `build/install-*.sh`
- copies shell config and the baked default OpenCode config from `config/`

This means most repo changes affect image contents indirectly through vendored files and installer scripts rather than through application source code.

### 2. `docker-compose.yml` is the local runtime contract

The compose file defines the canonical local workflow:

- builds the image from the repo root
- tags the image with the repository version
- mounts `${PROJECT_DIR:-.}` to `/workspace`
- optionally loads `.env`

The image itself now owns the default OpenCode global config at `/root/.config/opencode/config.json`. Repository-managed global skills are exposed through `/root/.config/opencode/skills`, and project-specific OpenCode settings should live in the mounted project's own `opencode.json`.

### 3. Vendoring is a first-class design choice

The project intentionally vendors three asset families under `vendor/`:

- release artifacts used by build scripts: `vendor/releases/`
- shell plugin source snapshots: `vendor/zsh/`
- OpenCode extensions: `vendor/opencode/`

`build/update-vendor-assets.sh` is the refresh mechanism for all three. It downloads pinned upstream artifacts or tarball snapshots, replaces the vendored copies, and leaves repository-managed global OpenCode skills in `vendor/opencode/skills/` intact.

`vendor/manifest.lock.json` is the machine-readable inventory for these vendored assets. If vendored refs or versions change, update the manifest alongside the files.

### 4. OpenCode extensions are split into plugin packages vs repo-managed global skills

OpenCode assets are deliberately separated:

- `vendor/opencode/packages/` contains full upstream plugin package snapshots
- `vendor/opencode/skills/` is reserved for repository-managed global skills

This split matters because `superpowers` is not just a folder of `SKILL.md` files. Its plugin entrypoint lives at `.opencode/plugins/superpowers.js` and resolves `../../skills` relative to that file. Because of that:

- the package root must stay intact under `vendor/opencode/packages/superpowers`
- the image preinstalls a symlink at `/root/.config/opencode/plugins/superpowers.js`
- `config/opencode.json` should only define image-level provider defaults
- repository-managed global skills are exposed via `/root/.config/opencode/skills -> /opt/vendor/opencode/skills`
- do not manually add `superpowers/skills` to `skills.paths`; the plugin registers its own bundled skills at runtime

If future work adds more OpenCode extensions, keep this distinction: full upstream plugins go under `vendor/opencode/packages/`, while repo-authored standalone skills go under `vendor/opencode/skills/`.

### 5. Documentation is split by audience

- `README.md` / `README_EN.md`: user-facing usage and container startup
- `DEVELOPMENT.md`: maintainer rules such as versioning, releases, issue conventions, and vendored-asset rules
- `docs/vendor-assets.md`: authoritative explanation of why vendored assets exist and how they are refreshed

For behavior changes, update the audience-appropriate docs rather than duplicating the same detail everywhere.

## Repository-specific constraints

- Do not treat `vendor/opencode/packages/superpowers` as a normal local refactor target unless the task is explicitly about updating the vendored upstream package.
- When updating vendored OpenCode packages, preserve upstream package-root layout. Do not flatten only `.opencode/plugins/*.js` or only copy `skills/`.
- `vendor/opencode/skills/` is intentionally outside the destructive refresh path in `build/update-vendor-assets.sh`; keep it that way.
- Prefer `uv run ...` over bare `python` for one-off scripted shell work in this repo.
- If creating GitHub issues for this repo, maintainers prefer GitHub issue forms via the Web UI; `gh issue create` does not automatically apply those forms.
