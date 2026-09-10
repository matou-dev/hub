---
type: ruling
status: active
maturity: unrated
scope: hub
roadmap: -
---

# CI sibling checkouts pin ref — GITHUB_TOKEN cannot see across repos

Date: 2026-09-09 (dependabot tranche: checkout v7.0.1 + setup-java v6.0.0)
Status: active

## Problem

Every `check.yml` that clones a sibling (`repository: matou-dev/<other>`)
without an explicit `ref` died before the gate ever ran:
`Determining the default branch` → `Not Found -
https://docs.github.com/rest/repos/repos#get-a-repository`, retried twice,
job red. `GITHUB_TOKEN` is scoped to the running repo, so the
default-branch API lookup 404s on any other repo — public or not. Both
checkout v4 and v7 resolve the default branch through that API call, so
the dependabot v4→v7 bump changed nothing: 6/8 repos were red on main
(hub, 4 bridges, example1, minimap), only same-repo checkouts (spi) ever
green. The redness predated the bump and would have survived it.

## Decision

1. Every cross-repo `actions/checkout` step pins `ref: main`. The
   self checkout (same repo, `path:` only) stays unpinned so
   `pull_request` runs keep testing their own merge commit.
2. Action SHAs stay pinned with Dependabot on top
   (checkout `3d3c42e5…` v7.0.1, setup-java `dd06d9cb…` v6.0.0,
   verified against the upstream tags before merge); the stale
   `(tag v4)` comments go with the bump.
3. A red main CI is a stop-the-line event, not background noise: this
   one hid behind "CI is flaky" while every push went red.

## Gates

- `gh run list --branch main` green on all 8 repos after the fix.
- A future sibling (see `BRIDGE_SCAFFOLD.md`) copies the `ref: main`
  pattern; a workflow without it fails its first PR loudly at the
  checkout step, never silently.

## What would re-open it

- A non-`main` default branch on any repo: the pin moves with the
  rename, same commit as the rename.
- checkout growing an offline default-branch fallback: re-prove by
  deleting one `ref:` on a scratch PR, never by assuming.
