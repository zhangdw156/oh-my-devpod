# oh-my-devpod

This package contains the complete `oh-my-devpod` runtime bundle and exposes
the `omd` command.

Supported host:

- Ubuntu 24.04
- Linux x64
- glibc
- Node.js 18 or newer

The package uses GitHub as its default release source. Select Gitee while
installing with:

```bash
OHMYDEVPOD_SOURCE=gitee npm install -g oh-my-devpod
```

Update npm-managed installations with:

```bash
npm update -g oh-my-devpod
```

npm updates retain the saved source choice. Set
the source independently of npm updates with:

```bash
omd --source gitee
omd --source github
```

This also migrates native source configuration for already installed,
OMD-managed Linuxbrew, uv, Micromamba, and pip environments. User-owned
configuration is preserved.

`omd --update` is reserved for bootstrap-managed installations and is rejected
in the npm package.
