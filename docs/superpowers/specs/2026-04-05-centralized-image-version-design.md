# Centralized Image Version Design

## Summary

Replace the current duplicated image tag management in pod-local compose files with one repository-root `VERSION` file. All four images (`devpod`, `openpod`, `claudepod`, `codexpod`) must derive their published version from that single text file.

## Motivation

The repository currently stores the same version string in multiple `docker/<flavor>/docker-compose.yaml` files. The publish workflow then parses those files and validates that the tags still match. This is workable, but it duplicates the same release state across multiple files and makes version bumps more fragile than necessary.

The desired workflow is simpler:

- one text file stores the shared version
- local compose and direct image references consume that version consistently
- the publish workflow reads the same version source directly

## Goals

- Introduce a repository-root `VERSION` file as the only version source for the four images.
- Remove hard-coded version strings from pod-local compose files.
- Make the GitHub Actions publish workflow read `VERSION` directly.
- Keep local pod-local compose workflows intact.
- Keep release and next-dev bump steps focused on updating a single file.

## Non-Goals

- Giving different versions to different flavors.
- Introducing a structured manifest format such as JSON or YAML for versioning.
- Changing image names or release channels.
- Reworking the current pod-local compose layout.

## Proposed Design

### 1. Root `VERSION` file

Add a root file named `VERSION` with exactly one version string, for example:

```text
0.4.0.dev5
```

This file becomes the single source of truth for:

- `oh-my-devpod`
- `oh-my-openpod`
- `oh-my-claudepod`
- `oh-my-codexpod`

### 2. Pod-local compose files

Each `docker/<flavor>/docker-compose.yaml` should stop embedding literal version strings in `image:` fields.

Instead, they should use `${IMAGE_VERSION}` with a safe local default so local compose usage still works without manual environment setup. The intended pattern is:

```yaml
image: oh-my-devpod:${IMAGE_VERSION:-local}
image: oh-my-openpod:${IMAGE_VERSION:-local}
```

And equivalently for `claudepod` and `codexpod`.

This keeps pod-local compose files usable for local development while removing them as the version authority.

### 3. Publish workflow

`.github/workflows/publish-ghcr.yml` should stop parsing pod-local compose files to resolve versions.

Instead, it should:

- read the root `VERSION` file
- trim trailing newlines
- reject empty values
- use that one value for all four GHCR image tags
- keep the current dev-version skip behavior

The workflow no longer needs to perform compose cross-file version consistency checks because the version source is already centralized.

### 4. Documentation

User and maintainer docs should explicitly state:

- `VERSION` is the only version source for all four images
- release cuts and next-dev bumps update only `VERSION`
- pod-local compose files are runtime entrypoints, not release metadata authorities

### 5. Regression tests

Shell tests should enforce the new contract:

- `VERSION` exists
- workflow reads `VERSION`
- pod-local compose files do not contain hard-coded repository version tags

## Data Flow

The new version data flow becomes:

1. Maintainer edits `VERSION`
2. Local compose uses `${IMAGE_VERSION:-local}` for developer runs
3. Workflow reads `VERSION`
4. Workflow publishes all four images with the same tag

## Error Handling

- If `VERSION` is missing, tests and workflow should fail immediately.
- If `VERSION` is empty or malformed, workflow should fail before any publish steps.
- If a compose file reintroduces a hard-coded release tag, tests should fail.

## Testing Strategy

- Update existing shell tests to assert the new version contract.
- Run `bash tests/run.sh`.
- Verify that the publish workflow’s version-resolution logic reads `VERSION`.
- Smoke-check at least one pod-local compose command after the compose interpolation change.

## Rollout

This change can ship in one step because all four images already share a single version semantically. The implementation is a source-of-truth simplification rather than a behavioral split.
