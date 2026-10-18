# Phase 1: repo tooling + Forgejo CI

This adds **only evaluation and local build tools**, not automatic deployment.

## Laptop

Install `just`, `nixfmt` and Nix with flakes enabled; then run:

```sh
just --list
just hosts
just check
just eval mimir
just build mimir
```

`just fmt-check` uses `nixfmt` to check tracked `.nix` files; it is intentionally **not** part of the initial CI workflow, because the existing repository may contain formatting differences. Run `just fmt` on a separate formatting-only commit.

## Forgejo

1. Set up a Forgejo Actions runner with the label `nixos` (or change `runs-on` in the workflow to match your runner).
2. The runner needs Nix installed, experimental features `nix-command` and `flakes`, outbound access to flake inputs, enough store capacity, and access to any private Git inputs.
3. Enable Actions in your Forgejo installation and repository.
4. Push the new workflow, and verify a run before requiring checks on pull requests.

For safety, use an isolated runner without production SSH keys or deployment secrets. This workflow does **not** build complete hosts and does **not** deploy anything. `nix flake check --no-build` evaluates registered checks but does not prove that full system builds succeed.

## Notes

The globally installed `/etc/just/Justfile` in `modules/just/base.just` is not changed. The root-level `justfile` is a separate convenience interface when working inside this repository.
