#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
export HOME="${tmp_dir}/test account"
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME OHMYDEVPOD_STATE_DIR OHMYDEVPOD_MANAGED_DIR
module="${repo_root}/modules/tools/zsh-config.sh"
prefix="${HOME}/.linuxbrew"
mkdir -p "${prefix}/bin"
cat > "${prefix}/bin/zsh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$1" "${PROFILE_SETTING}" >> "$HOME/zsh-entered"
printenv SHELL >> "$HOME/zsh-entered"
STUB
chmod +x "${prefix}/bin/zsh"
printf 'export PROFILE_SETTING=user' > "${HOME}/.profile"
cp "${HOME}/.profile" "${tmp_dir}/original"

# A personal formula installed outside OMD keeps its existing login behavior.
"${module}" install >/dev/null
cmp "${HOME}/.profile" "${tmp_dir}/original"
# shellcheck source=../modules/lib/common.sh
source "${repo_root}/modules/lib/common.sh"
omd_module_mark_managed zsh brew-formula zsh "brew_prefix=$(cd "${prefix}" && pwd -P)"
"${module}" update > "${tmp_dir}/install.out"
grep -Fq 'exec "$HOME/.linuxbrew/bin/zsh" -l' "${tmp_dir}/install.out"
cp "${HOME}/.profile" "${tmp_dir}/installed"
"${module}" install >/dev/null
cmp "${HOME}/.profile" "${tmp_dir}/installed"

# Keep /etc/profile out of the fixture. The SSH acceptance suite runs an actual sshd.
python3 - <<'PY'
import os
import pathlib
import pty
import subprocess

home = pathlib.Path.home()
marker = home / "zsh-entered"
inherited_shell = home / "shell-after-profile"
for flags, ssh, expect_zsh in [
    (["-il"], True, True),
    (["-il"], False, False),
    (["-i"], True, False),
    (["-l", "-c"], True, False),
    (["-il", "-c"], True, False),
]:
    master, slave = pty.openpty()
    try:
        env = dict(os.environ, SSH_TTY=os.ttyname(slave) if ssh else "", PS1="", SHELL="/bin/bash")
        command = '. "$HOME/.profile"\nprintenv SHELL > "$HOME/shell-after-profile"\nexit\n'
        args = ["bash", "--noprofile", "--norc", *flags]
        if "-c" in flags:
            args.append(command)
        with subprocess.Popen(args, env=env, stdin=slave, stdout=slave, stderr=slave) as shell:
            if "-c" not in flags:
                os.write(master, command.encode())
            assert shell.wait(timeout=10) == 0
        assert marker.exists() == expect_zsh, (flags, ssh, (home / ".profile").read_text())
        if expect_zsh:
            assert marker.read_text() == f"-l\nuser\n{home}/.linuxbrew/bin/zsh\n", marker.read_text()
            marker.unlink()
        else:
            assert inherited_shell.read_text() == "/bin/bash\n"
            inherited_shell.unlink()
    finally:
        os.close(slave)
        os.close(master)
PY

# The command shown after installation must activate the same shell for children.
activation_command="$(sed -n 's/^notice: To use Zsh in this terminal, run: //p' "${tmp_dir}/install.out")"
[[ -n "${activation_command}" ]]
SHELL=/bin/bash PROFILE_SETTING=manual bash --noprofile --norc -c "${activation_command}"
cmp "${HOME}/zsh-entered" <(printf '%s\n' '-l' manual "${prefix}/bin/zsh")
rm "${HOME}/zsh-entered"

# Bash now picks a different startup file. Restore the original .profile byte for byte.
touch "${HOME}/.bash_login"
"${module}" update >/dev/null
cmp "${HOME}/.profile" "${tmp_dir}/original"
grep -Fq '# oh-my-devpod SSH login' "${HOME}/.bash_login"
cp "${HOME}/.bash_login" "${tmp_dir}/login-hook"
sed 's/^if /# disabled: if /' "${HOME}/.bash_login" > "${tmp_dir}/disabled"
cp "${tmp_dir}/disabled" "${HOME}/.bash_login"
"${module}" update >/dev/null
cmp "${HOME}/.bash_login" "${tmp_dir}/disabled"
cp "${tmp_dir}/login-hook" "${HOME}/.bash_login"
printf '%s\n' '# kept after uninstall' >> "${HOME}/.bash_login"
"${module}" uninstall >/dev/null
cmp "${HOME}/.bash_login" <(printf '%s\n' '# kept after uninstall')

ln -s "${tmp_dir}/original" "${HOME}/.bash_profile"
"${module}" install >/dev/null
"${module}" uninstall >/dev/null
[[ -L "${HOME}/.bash_profile" ]]
cmp "${tmp_dir}/original" <(printf 'export PROFILE_SETTING=user')
