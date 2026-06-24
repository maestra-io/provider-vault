# Maestra fork of upbound/provider-vault

This is a thin GitHub fork of [`upbound/provider-vault`](https://github.com/upbound/provider-vault),
based on tag **`v4.0.0`**, carrying a single behavioural patch plus a
self-contained build/release pipeline that publishes to Maestra's ECR.

## The patch

`config/database/config.go` makes the root `password` of
`vault_database_secret_backend_connection` **create-only**: it is sent to Vault
on the initial Create but never re-sent on Update/reconcile/cold-start.

**Why.** Vault's `database/config/<name>` read API never returns the password,
so Upjet's diff perpetually sees the password (resolved from `passwordSecretRef`)
as a change and re-applies it on every reconcile — clobbering a `rotate-root`'d
root password and breaking dynamic credential issuance (28P01). This is
[upbound/provider-vault#38](https://github.com/upbound/provider-vault/issues/38).

The fix is an Upjet `TerraformCustomDiff` that drops `<engine>.0.password` from
the Update diff (keyed on a non-empty Terraform state ID) while leaving the
Create diff intact. It is the Crossplane-native equivalent of the
`lifecycle.ignore_changes = [<engine>[0].password]` already relied upon on the
Terraform side in `maestra-io/vault`.

This lets the Crossplane composition use the **normal** full
`managementPolicies: [Create, Update, Observe, Delete]` + `passwordSecretRef`
flow — no `Observe`-only / deny-update workaround, and it eliminates the
403-collision (`create+delete` policy without `update` on an already-existing
path).

The Go module path stays `github.com/upbound/provider-vault/v4` (the upjet
codegen bakes it into thousands of files); only the repo home and the
image/xpkg registry are Maestra's.

## Build & release

Self-contained `Makefile` (no upbound `build/` submodule), mirroring
`maestra-io/provider-cloudflare`:

```bash
make build              # per-arch provider binary -> _output/<os>_<arch>/provider
make image              # host-arch OCI image (distroless)
make xpkg.build         # crossplane xpkg with embedded runtime image
make image.buildx.push  # multi-arch image -> ECR  (CI)
make xpkg.push          # xpkg -> ECR provider-vault-pkg  (CI)
```

CI (`.github/workflows/release.yml`) builds + pushes on a `v*` tag:

- image:  `515260921971.dkr.ecr.eu-central-1.amazonaws.com/provider-vault:<tag>`
- xpkg:   `515260921971.dkr.ecr.eu-central-1.amazonaws.com/provider-vault-pkg:<tag>`

ECR auth is via Teleport workload-identity (join token
`image-push-github-actions-provider-vault`), same pattern as provider-cloudflare.

### Versioning

Tags follow `v<upstream>-maestra.<n>`, e.g. `v4.0.0-maestra.1`. The
`<upstream>` part tracks the upstream release this fork is based on; `<n>`
increments for Maestra-only changes on top of it.

## Pulling upstream updates

```bash
git fetch upstream
git merge upstream/main          # or a specific upstream tag, e.g. v4.1.0
# resolve conflicts (our changes are isolated to config/database/, a 3-line
# config/provider.go wiring, Makefile, Dockerfile, package/crossplane.yaml.tmpl
# and .github/), then tag v<new-upstream>-maestra.1
```
