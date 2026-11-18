#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
python3 - <<'PY'
import re
from pathlib import Path

pages = [
    ('README.md', 'Readme.osc.md', 'docs/guide.md',
     'raw.githubusercontent.com', ['install', 'prerequisites', 'switch-sources', 'update', 'shared-servers', 'tui-and-cli']),
    ('Readme.osc.md', 'README.md', 'docs/guide.zh-CN.md',
     'gitee.com', ['安装', '系统依赖', '切换软件源', '更新', '多人服务器', 'tui-与-cli']),
]
for filename, other, guide, forge, sections in pages:
    page = Path(filename).read_text()
    targets = set(re.findall(r'(?:\]\(|(?:href|src)=")(\./[^)"\s]+)', page))
    required = {f'./{other}', './docs/assets/omd-hero.svg', './docs/assets/omd-demo.gif',
                './DEVELOPMENT.md', './docs/npm-release.md'}
    required.update(f'./{guide}#{section}' for section in sections)
    assert required <= targets, (filename, required - targets)
    for link in targets:
        name, _, fragment = link.partition('#')
        target = Path(name)
        assert target.is_file(), (filename, link)
        if fragment:
            headings = re.findall(r'^#{1,6} (.+)$', target.read_text(), re.M)
            assert fragment in {h.lower().replace(' ', '-') for h in headings}, (filename, link)
    for word in ['20.04', '22.04', '24.04', '26.04', 'x86_64', 'omd --plan install lazyvim',
                 'omd --list-components', '~/.linuxbrew']:
        assert word in page, (filename, word)
    install = re.search(r'```bash\n(curl [^`]+)\n```', page)[1]
    assert forge in install and 'install/bootstrap.sh' in install, (filename, install)
    if forge == 'gitee.com':
        assert 'OHMYDEVPOD_SOURCE=gitee bash' in install
assert './README.md' in Path('README_EN.md').read_text()
assert Path('docs/assets/omd-demo.gif').read_bytes().startswith(b'GIF89a')
PY
