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
`OHMYDEVPOD_SOURCE=github|gitee` during an update only when changing it.
`omd --update` is reserved for bootstrap-managed installations and is rejected
in the npm package.
