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
mkdir -p "${settings_dir}"

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
