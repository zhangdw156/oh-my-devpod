# npm release

The public npm package is named `oh-my-devpod` and exposes the `omd` command.
The npm tarball must always be assembled from the same complete release archive
published to GitHub and Gitee. Supported hosts are Ubuntu 22.04, 24.04, and
26.04 on x86_64.

## One-time registry bootstrap

npm trusted publishing can only be configured after the package exists. The
first release therefore requires one authenticated manual publication:

1. Run the `release-omd` workflow manually on the release commit and confirm
   that compatibility checks passed on all three supported Ubuntu versions.
2. Download the `oh-my-devpod-npm` workflow artifact.
3. Authenticate with an npm account authorized to own `oh-my-devpod`.
4. Publish the generated tarball:

   ```bash
   npm publish oh-my-devpod-<version>.tgz --access public
   ```

5. In the npm package settings, configure GitHub Actions as a trusted publisher:
   - repository owner: `zhangdw156`
   - repository: `oh-my-devpod`
   - workflow: `release-omd.yml`
6. Remove any temporary npm token used for the bootstrap publication.

Do not publish directly from the source `npm/` directory. It does not contain
the runtime payload until `build/package-npm.sh` assembles the release tarball.

## Normal releases

The root `VERSION`, `crates/omd/Cargo.toml`, and `npm/package.json` versions must
match. Push the matching `v<version>` tag. The release workflow:

1. builds the Linux x86_64 release binary on Ubuntu 22.04 with a Python 3.12
   toolchain;
2. creates the GitHub/Gitee release archive and checksum;
3. creates the npm package from that archive;
4. tests that same release archive and npm package on Ubuntu 22.04, 24.04, and
   26.04 before publishing any release artifacts;
5. publishes stable versions with the `latest` npm tag and prereleases with
   `next`;
6. authenticates through npm trusted publishing and emits provenance.

The npm publish job is idempotent: rerunning a release whose npm version already
exists skips the immutable version instead of failing the GitHub release.

## Local compatibility verification

Build on Ubuntu 22.04 x86_64 with a Python 3.12 toolchain, then test the exact
release archive and npm tarball that will be published.

The test requires a running Docker daemon and network access to fetch Ubuntu
images, Node.js, and container test dependencies.

```bash
bash tests/test-ubuntu-compatibility.sh <release.tar.gz> <package.tgz>
```

The default run covers Ubuntu 22.04, 24.04, and 26.04. Optional trailing
versions, such as `22.04 26.04`, select a subset for local checks. All three
versions must pass before publication; do not rebuild either artifact between
verification and publication. Python 3.12 is required for maintainer builds
and tests, not as the installed host's system Python.

## Installation source

The default npm source profile is GitHub/upstream:

```bash
npm install --global oh-my-devpod
```

Select the Gitee/China mirror profile during installation:

```bash
OHMYDEVPOD_SOURCE=gitee npm install --global oh-my-devpod
```

The selected profile is stored under the user's oh-my-devpod configuration and
is retained by later npm updates unless `OHMYDEVPOD_SOURCE` explicitly changes
it.

npm owns npm installations. Update them with:

```bash
npm update --global oh-my-devpod
```

The bundled `omd --update` command rejects npm-managed installations.
