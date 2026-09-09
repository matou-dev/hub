# matou-dev — hub doctrine (org SSOT pointer)

See `AGENTS.md`.

## Checkout convention

Clone the 8 repos as siblings (`hub spi bridge-1710 bridge-1122 bridge-1201
bridge-1165 example1 minimap` in one folder): the `AGENTS.md` pointers resolve `../hub` with no network.
Repos are private during dev: authenticated clone required
(`gh auth login`, else 404 on clone).

## Tools

- `tools/scaffold-bridge.sh --help`: scaffolds a new `bridge-<sfx>`
  (etages 1+2 green without MC, live run as a loud TODO placeholder) from
  `tools/bridge-template/` plus version-independent copies from a `--ref`
  bridge. Measured pins are never defaulted: the placeholder fails with
  `LIVE=1` until the live run is ported.
- `tools/check-bridges.sh`: N-bridge parity over `../bridge-*/` (same
  `SPI_PIN`, same `forge/` file-set, same `E_FORGE_*` catalog).
- `tools/run-client.sh` (`--bridge <dir>` or `BRIDGE`, else the bridge
  `tools/run-client.sh` wrapper): stages a Prism Launcher dev-client
  instance (DEV build + content) for any bridge; per-version table in
  `tools/client-common.sh` (1165 proven, other rows experimental/untested).
  `tools/verify-client-save.sh` replays the live verdict on the client
  save. NOT a gate (needs display + Prism + a provisioned live dir).
  `PRISM_DIR` must be an isolated root (the live Prism home is refused
  loudly). `AUTOPLAY=1` (1165 only) stages a dev-only companion that
  plays the proof without a keyboard (`XVFB=1` headless, `AUTOVERIFY=1`
  replays the verdict on exit).
- `.vscode/tasks.json`: the same dev-client tasks for editors (bridge
  picker input; bridge repos keep their own gate-oriented tasks).
