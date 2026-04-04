#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_home="$(mktemp -d)"
trap 'rm -rf "${tmp_home}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

settings_dir="${tmp_home}/.claude"
settings_file="${settings_dir}/settings.json"
workspace_dir="${tmp_home}/workspace"
mkdir -p "${settings_dir}"
mkdir -p "${workspace_dir}"

cat > "${settings_file}" <<'JSON'
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
  use strict;
  use warnings;

  my ($settings_path) = @ARGV;
  open my $fh, "<", $settings_path or die $!;
  local $/;
  my $data = decode_json(<$fh>);

  die "missing env\n" unless $data->{env};
  die "missing api key\n" unless $data->{env}{ANTHROPIC_API_KEY} eq "sk-ant-test";
  die "missing base url\n" unless $data->{env}{ANTHROPIC_BASE_URL} eq "https://gateway.example.com";
  die "lost permissions\n" unless $data->{permissions}{defaultMode} eq "default";
' "${settings_file}" || fail "managed env keys were not merged into settings.json"

cat > "${workspace_dir}/.env" <<'ENV'
ANTHROPIC_API_KEY=sk-ant-workspace
ANTHROPIC_BASE_URL=https://workspace-gateway.example.com
ENV

rm -f "${settings_file}" "${settings_dir}/oh-my-claudepod-state.json"

(
  cd "${workspace_dir}"
  env \
    HOME="${tmp_home}" \
    bash "${repo_root}/bin/claudepod-sync-config"
)

perl -MJSON::PP -e '
  use strict;
  use warnings;

  my ($settings_path) = @ARGV;
  open my $fh, "<", $settings_path or die $!;
  local $/;
  my $data = decode_json(<$fh>);

  die "missing env from workspace fallback\n" unless $data->{env};
  die "missing workspace api key\n" unless $data->{env}{ANTHROPIC_API_KEY} eq "sk-ant-workspace";
  die "missing workspace base url\n" unless $data->{env}{ANTHROPIC_BASE_URL} eq "https://workspace-gateway.example.com";
' "${settings_file}" || fail "workspace .env fallback did not populate settings.json"
