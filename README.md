# odoo-docker-master

The base image Odoo does not publish: **master** (the future 20.0), packaged the
same way [`odoo/docker`](https://github.com/odoo/docker) packages 17.0/18.0/19.0.

Docker Hub ships `odoo:17.0`, `odoo:18.0`, `odoo:19.0` — and nothing for the
development series. Odoo has not branched 20.0; that work lives on `master`,
which currently self-reports as `19.5a1`. This repo fills the gap.

## Usage

```dockerfile
FROM ghcr.io/indexa-git/odoo:master
```

exactly the way you would write `FROM odoo:19.0` on the 19.0 line.

The package is **private**. Consumers authenticate with `GITHUB_TOKEN` and must
be granted read access to it under *package settings > Manage Actions access*:

```yaml
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

From a laptop, log in with a classic PAT carrying `read:packages`:

```bash
echo $CR_PAT | docker login ghcr.io -u USERNAME --password-stdin
docker pull ghcr.io/indexa-git/odoo:master
```

## Tags

| tag | meaning |
|---|---|
| `master` | moving, latest build |
| `master-<YYYYMMDD>` | immutable, for pinning |

Platforms: `linux/amd64`, `linux/arm64`.

## What it is

A faithful copy of the official `odoo/docker` 19.0 recipe — same base
(`ubuntu:noble`), same deps, same `entrypoint.sh`, `odoo.conf`,
`wait-for-psql.py`, volumes and ports. One difference: the core comes from the
**master nightly `.deb`** instead of a released one.

The `.deb` filename and its sha1 are resolved from the nightly `Packages` index
at build time rather than pinned, so this keeps working when master renames
itself from `19.5a1` to `20.0a1`.

To pin an exact nightly, run the workflow manually with:

- `odoo_deb` — e.g. `odoo_19.5a1.20260901_all.deb`
- `odoo_sha` — its sha1

## Publishing

`.github/workflows/build.yaml` builds and pushes on changes to the recipe,
weekly (Monday 06:00 UTC) to pick up the week's nightly, or on demand.

It authenticates with `GITHUB_TOKEN`, which is what GitHub recommends for
workflows, and which also links the package to this repository automatically.

Note that linking does not make the package public: GHCR packages are private on
first publish regardless of the repository's visibility, and this one is
deliberately left private.

## Lifecycle

**Archive this repo once Odoo publishes a real `odoo:20.0` image**, and switch
consumers back to `FROM odoo:20.0`.
