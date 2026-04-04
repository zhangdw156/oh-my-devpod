# `dev/claude` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the OpenCode runtime with Claude Code on the long-lived `dev/claude` branch while preserving the container/bootstrap developer experience and renaming public artifacts to `oh-my-claudepod`.

**Architecture:** Install Claude Code through Anthropic's native Linux installer, wrap the real `claude` binary with a repo-managed sync script that materializes managed settings from `.env` into `~/.claude/settings.json`, and migrate vendored AI assets from OpenCode-specific layout to Claude-oriented skills layout. Keep shared shell/editor/runtime infrastructure intact and rewrite public entrypoints, docs, and smoke checks to Claude semantics.

**Tech Stack:** Bash, Perl (`JSON::PP`), Docker, docker compose, vendored shell assets, Claude Code native installer, shell-based smoke tests

---

### Task 1: Add Failing Coverage For Claude Wrappers And Config Sync

**Files:**
- Create: `tests/test-claudepod-sync-config.sh`
- Create: `tests/test-claudepod-shell-wrappers.sh`
- Modify: `tests/run.sh`

- [ ] **Step 1: Write the failing sync test**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_home="$(mktemp -d)"
trap 'rm -rf "${tmp_home}"' EXIT

settings_dir="${tmp_home}/.claude"
mkdir -p "${settings_dir}"
cat > "${settings_dir}/settings.json" <<'JSON'
{
  "permissions": {
    "defaultMode": "default"
  }
}
JSON

env \
  HOME="${tmp_home}" \
  ANTHROPIC_API_KEY="sk-ant-test" \
  ANTHROPIC_BASE_URL="https://gateway.example.com" \
  bash "${repo_root}/bin/claudepod-sync-config"

perl -MJSON::PP -e '
  my $file = shift;
  open my $fh, "<", $file or die $!;
  local $/;
  my $data = decode_json(<$fh>);
  die "missing env" unless $data->{env};
  die "missing api key" unless $data->{env}{ANTHROPIC_API_KEY} eq "sk-ant-test";
  die "missing base url" unless $data->{env}{ANTHROPIC_BASE_URL} eq "https://gateway.example.com";
  die "lost permissions" unless $data->{permissions}{defaultMode} eq "default";
' "${settings_dir}/settings.json"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-claudepod-sync-config.sh`
Expected: FAIL with `No such file or directory` for `bin/claudepod-sync-config`

- [ ] **Step 3: Write the failing wrapper test**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_home="$(mktemp -d)"
trap 'rm -rf "${tmp_home}"' EXIT

mkdir -p "${tmp_home}/bin"
cat > "${tmp_home}/bin/claude-real" <<'SH'
#!/usr/bin/env bash
printf 'real:%s\n' "$*"
SH
chmod +x "${tmp_home}/bin/claude-real"

output="$(
  env \
    HOME="${tmp_home}" \
    OPENPOD_CLAUDE_REAL_BIN="${tmp_home}/bin/claude-real" \
    bash "${repo_root}/bin/claude" --version
)"

printf '%s' "${output}" | grep -q 'real:--version'
```

- [ ] **Step 4: Run test to verify it fails**

Run: `bash tests/test-claudepod-shell-wrappers.sh`
Expected: FAIL with `No such file or directory` for `bin/claude`

- [ ] **Step 5: Register the new tests in the suite**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "${repo_root}/tests/test-install-neovim.sh"
bash "${repo_root}/tests/test-install-python-dev-tools.sh"
bash "${repo_root}/tests/test-install-lazyvim.sh"
bash "${repo_root}/tests/test-neovim-lazyvim-wiring.sh"
bash "${repo_root}/tests/test-claudepod-sync-config.sh"
bash "${repo_root}/tests/test-claudepod-shell-wrappers.sh"
```

- [ ] **Step 6: Commit**

```bash
git add tests/run.sh tests/test-claudepod-sync-config.sh tests/test-claudepod-shell-wrappers.sh
git commit -m "test: add claudepod wrapper coverage"
```

### Task 2: Implement Claude Install, Wrapper, And Managed Settings Sync

**Files:**
- Create: `bin/claude`
- Create: `bin/claudepod-sync-config`
- Create: `bin/claudepod-shell`
- Create: `build/install-claude-code.sh`
- Create: `config/claude/settings.base.json`
- Modify: `bin/openpod-shell`

- [ ] **Step 1: Write the minimal managed settings template**

```json
{
  "permissions": {
    "defaultMode": "acceptEdits"
  }
}
```

- [ ] **Step 2: Implement the sync script with Perl JSON merging**

```bash
#!/usr/bin/env bash
set -euo pipefail

claude_dir="${HOME}/.claude"
settings_file="${claude_dir}/settings.json"
state_file="${claude_dir}/oh-my-claudepod-state.json"
base_template="${OPENPOD_CLAUDE_BASE_SETTINGS:-}"
mkdir -p "${claude_dir}"

perl -MJSON::PP -e '
  use strict;
  use warnings;

  my ($settings_file, $state_file, $base_template) = @ARGV;
  my %managed_env;
  for my $key (qw(
    ANTHROPIC_API_KEY
    ANTHROPIC_AUTH_TOKEN
    ANTHROPIC_BASE_URL
    ANTHROPIC_BEDROCK_BASE_URL
    ANTHROPIC_VERTEX_BASE_URL
    ANTHROPIC_VERTEX_PROJECT_ID
    ANTHROPIC_MODEL
    ANTHROPIC_SMALL_FAST_MODEL
    CLAUDE_CODE_USE_BEDROCK
    CLAUDE_CODE_USE_VERTEX
    CLAUDE_CODE_SKIP_BEDROCK_AUTH
    CLAUDE_CODE_SKIP_VERTEX_AUTH
    AWS_REGION
    AWS_PROFILE
    AWS_BEARER_TOKEN_BEDROCK
    CLOUD_ML_REGION
    GOOGLE_APPLICATION_CREDENTIALS
    GCLOUD_PROJECT
    GOOGLE_CLOUD_PROJECT
    DISABLE_AUTOUPDATER
  )) {
    next unless defined $ENV{$key} && length $ENV{$key};
    $managed_env{$key} = $ENV{$key};
  }

  sub read_json {
    my ($path, $default) = @_;
    return $default unless -f $path;
    open my $fh, "<", $path or die $!;
    local $/;
    my $raw = <$fh>;
    return $default unless defined $raw && length $raw;
    return decode_json($raw);
  }

  my $settings = read_json($settings_file, {});
  my $base = $base_template && -f $base_template ? read_json($base_template, {}) : {};
  my $state = read_json($state_file, { managed_env_keys => [] });

  for my $key (keys %{$base}) {
    $settings->{$key} = $base->{$key} unless exists $settings->{$key};
  }

  $settings->{env} ||= {};
  for my $key (@{$state->{managed_env_keys}}) {
    delete $settings->{env}{$key} unless exists $managed_env{$key};
  }
  for my $key (keys %managed_env) {
    $settings->{env}{$key} = $managed_env{$key};
  }
  delete $settings->{env} unless keys %{$settings->{env}};

  open my $out, ">", $settings_file or die $!;
  print {$out} JSON::PP->new->ascii->pretty->canonical->encode($settings);

  open my $state_out, ">", $state_file or die $!;
  print {$state_out} JSON::PP->new->ascii->pretty->canonical->encode({
    managed_env_keys => [ sort keys %managed_env ],
  });
' "${settings_file}" "${state_file}" "${base_template}"
```

- [ ] **Step 3: Implement the Claude wrapper and shell entrypoint**

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${OPENPOD_CLAUDE_SYNC_BIN:-}" && -x "${OPENPOD_CLAUDE_SYNC_BIN}" ]]; then
  "${OPENPOD_CLAUDE_SYNC_BIN}"
fi

real_bin="${OPENPOD_CLAUDE_REAL_BIN:-}"
if [[ -z "${real_bin}" || ! -x "${real_bin}" ]]; then
  echo "claude real binary not found" >&2
  exit 1
fi

exec "${real_bin}" "$@"
```

- [ ] **Step 4: Implement the Claude installer helper**

```bash
#!/usr/bin/env bash
set -euo pipefail

claude_home="${OPENPOD_CLAUDE_INSTALL_HOME:?missing OPENPOD_CLAUDE_INSTALL_HOME}"
target_bin_dir="${OPENPOD_BIN_DIR:?missing OPENPOD_BIN_DIR}"
mkdir -p "${target_bin_dir}"

env HOME="${claude_home}" PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'

real_bin="$(readlink -f "${claude_home}/.local/bin/claude")"
ln -sfn "${real_bin}" "${target_bin_dir}/claude-real"
```

- [ ] **Step 5: Update the compatibility shell wrapper**

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/claudepod-shell" "$@"
```

- [ ] **Step 6: Run the new focused tests and verify green**

Run: `bash tests/test-claudepod-sync-config.sh`
Expected: PASS

Run: `bash tests/test-claudepod-shell-wrappers.sh`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add bin/claude bin/claudepod-sync-config bin/claudepod-shell bin/openpod-shell build/install-claude-code.sh config/claude/settings.base.json
git commit -m "feat: add claudepod runtime wrappers"
```

### Task 3: Switch Docker And Bootstrap To Claude Code

**Files:**
- Modify: `Dockerfile`
- Modify: `install/bootstrap.sh`
- Modify: `docker-compose.yml`

- [ ] **Step 1: Update Dockerfile installation and config paths**

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    bzip2 \
    curl \
    fd-find \
    file \
    gcc \
    git \
    make \
    perl \
    ripgrep \
    tzdata \
    unzip \
    vim \
    zsh \
    ca-certificates \
    musl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.claude \
    && ln -sfn /opt/vendor/claude/skills /root/.claude/skills

COPY build/install-claude-code.sh /tmp/install-claude-code.sh
RUN OPENPOD_BIN_DIR=/usr/local/bin OPENPOD_CLAUDE_INSTALL_HOME=/root bash /tmp/install-claude-code.sh \
    && rm -f /tmp/install-claude-code.sh

COPY bin/claude /usr/local/bin/claude
COPY bin/claudepod-sync-config /usr/local/bin/claudepod-sync-config
COPY bin/claudepod-shell /usr/local/bin/claudepod-shell
COPY bin/openpod-shell /usr/local/bin/openpod-shell
COPY config/claude/settings.base.json /opt/openpod-config/claude/settings.base.json
ENV OPENPOD_CLAUDE_REAL_BIN=/usr/local/bin/claude-real
ENV OPENPOD_CLAUDE_SYNC_BIN=/usr/local/bin/claudepod-sync-config
ENV OPENPOD_CLAUDE_BASE_SETTINGS=/opt/openpod-config/claude/settings.base.json
```

- [ ] **Step 2: Update bootstrap install flow**

```bash
config_home="${HOME}/.claude"
plugin_dir=""
skills_link="${config_home}/skills"

mkdir -p "${config_home}" "${data_home}" "${state_home}" "${cache_home}" "${shell_dir}"
cp "${repo_root}/config/claude/settings.base.json" "${config_home}/settings.json"
ln -sfn "${vendor_home}/claude/skills" "${skills_link}"

export OPENPOD_CLAUDE_INSTALL_HOME="${HOME}"
bash "${repo_root}/build/install-claude-code.sh"
install -m 0755 "${repo_root}/bin/claude" "${bin_dir}/claude"
install -m 0755 "${repo_root}/bin/claudepod-sync-config" "${bin_dir}/claudepod-sync-config"
install -m 0755 "${repo_root}/bin/claudepod-shell" "${bin_dir}/claudepod-shell"
install -m 0755 "${repo_root}/bin/openpod-shell" "${bin_dir}/openpod-shell"
```

- [ ] **Step 3: Rename compose service and image**

```yaml
services:
  claudepod:
    build:
      context: .
      network: host
    image: oh-my-claudepod:0.4.0.dev5
    container_name: claudepod
```

- [ ] **Step 4: Run syntax-level verification**

Run: `docker compose config`
Expected: PASS with service name `claudepod`

Run: `bash install/bootstrap.sh --help`
Expected: PASS with Claude-oriented wording

- [ ] **Step 5: Commit**

```bash
git add Dockerfile install/bootstrap.sh docker-compose.yml
git commit -m "feat: switch runtime to claude code"
```

### Task 4: Migrate Vendored AI Assets And Asset Metadata

**Files:**
- Create: `vendor/claude/skills/`
- Modify: `build/update-vendor-assets.sh`
- Modify: `vendor/manifest.lock.json`
- Modify: `docs/vendor-assets.md`
- Delete: `vendor/opencode/`

- [ ] **Step 1: Move the vendored skills tree into Claude layout**

```bash
mkdir -p vendor/claude/skills
cp -R vendor/opencode/packages/superpowers/skills vendor/claude/skills/superpowers
rm -rf vendor/opencode
```

- [ ] **Step 2: Update asset refresh script to vendor only Claude-oriented skills**

```bash
mkdir -p "${vendor_dir}/releases" "${vendor_dir}/nvim" "${vendor_dir}/zsh" "${vendor_dir}/claude/skills"

download_plugin_snapshot "obra/superpowers" "refs/tags/${superpowers_version}" "${tmp_dir}/superpowers"
rm -rf "${vendor_dir}/claude/skills/superpowers"
mkdir -p "${vendor_dir}/claude/skills/superpowers"
cp -R "${tmp_dir}/superpowers/skills/." "${vendor_dir}/claude/skills/superpowers/"
```

- [ ] **Step 3: Rewrite manifest entries**

```json
{
  "claude_code": {
    "install": {
      "method": "native-install-script",
      "source_url": "https://claude.ai/install.sh"
    },
    "vendored_skills": {
      "superpowers": {
        "repo": "obra/superpowers",
        "version": "v5.0.7",
        "local_path": "vendor/claude/skills/superpowers"
      }
    }
  }
}
```

- [ ] **Step 4: Rewrite human-facing asset docs**

```markdown
## Vendored Claude Assets

### Skills

| Component | Version | Local path | Upstream source |
|-----------|---------|------------|-----------------|
| superpowers skills snapshot | `v5.0.7` | `vendor/claude/skills/superpowers/` | `obra/superpowers` tag archive |

The Claude branch vendors the upstream `skills/` tree directly instead of keeping the OpenCode plugin wrapper.
```

- [ ] **Step 5: Run focused verification**

Run: `bash build/update-vendor-assets.sh`
Expected: PASS and recreate `vendor/claude/skills/superpowers`

- [ ] **Step 6: Commit**

```bash
git add build/update-vendor-assets.sh vendor/manifest.lock.json docs/vendor-assets.md vendor/claude
git rm -r vendor/opencode
git commit -m "refactor: migrate vendored ai assets to claude layout"
```

### Task 5: Rewrite Public Docs, Env Example, And Smoke Checks

**Files:**
- Modify: `.env.example`
- Modify: `README.md`
- Modify: `README_EN.md`

- [ ] **Step 1: Rewrite `.env.example` to Claude-supported surfaces**

```dotenv
# Anthropic direct
# ANTHROPIC_API_KEY=sk-ant-xxxxx

# Anthropic-compatible gateway
# ANTHROPIC_BASE_URL=https://gateway.example.com
# ANTHROPIC_AUTH_TOKEN=your-token

# Amazon Bedrock
# CLAUDE_CODE_USE_BEDROCK=1
# AWS_REGION=us-east-1

# Google Vertex AI
# CLAUDE_CODE_USE_VERTEX=1
# CLOUD_ML_REGION=global
# ANTHROPIC_VERTEX_PROJECT_ID=your-project-id
```

- [ ] **Step 2: Rewrite README runtime and config language**

```markdown
| **AI** | [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) | Terminal AI coding assistant |

The image exposes Claude skills through `/root/.claude/skills` and uses `.claude/settings.json` plus `CLAUDE.md` for project-level configuration.
```

- [ ] **Step 3: Replace smoke commands**

```bash
docker compose run --rm claudepod -lc 'claude --version'
docker compose run --rm claudepod -lc 'claude doctor'
```

- [ ] **Step 4: Add migration note**

```markdown
`dev/claude` does not use `opencode.json` or `~/.config/opencode`.
Project-level configuration now lives in `.claude/settings.json` and `CLAUDE.md`.
```

- [ ] **Step 5: Verify docs and examples stay consistent**

Run: `rg -n "opencode|OpenCode|~/.config/opencode|opencode.json" README.md README_EN.md .env.example`
Expected: only migration-note references remain

- [ ] **Step 6: Commit**

```bash
git add .env.example README.md README_EN.md
git commit -m "docs: rewrite claudepod user documentation"
```

### Task 6: End-To-End Verification For Docker, Bootstrap, And Test Suite

**Files:**
- Modify: `tests/run.sh` (if verification helpers need final adjustment)

- [ ] **Step 1: Run the shell-based test suite**

Run: `bash tests/run.sh`
Expected: PASS

- [ ] **Step 2: Build the Claude image**

Run: `docker compose build`
Expected: PASS and produce image `oh-my-claudepod:0.4.0.dev5`

- [ ] **Step 3: Verify runtime installation inside the container**

Run: `docker compose run --rm claudepod -lc 'claude --version && claude doctor'`
Expected: PASS

- [ ] **Step 4: Verify bootstrap flow in a temporary prefix**

Run: `tmp_prefix="$(mktemp -d)" && bash install/bootstrap.sh --user --prefix "${tmp_prefix}" && "${HOME}/.local/bin/claudepod-shell" -lc "claude --version"`
Expected: PASS

- [ ] **Step 5: Verify Claude-facing naming**

Run: `rg -n "oh-my-openpod:|container_name: openpod|services:\\s+openpod" Dockerfile docker-compose.yml README.md README_EN.md`
Expected: no matches

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: ship dev/claude claudepod branch"
```
