# matou-dev — hub doctrine (org SSOT pointer)

See `AGENTS.md`.

## Checkout convention

Clone the 7 repos as siblings (`hub spi bridge-1710 bridge-1122 bridge-1201
example1 minimap` in one folder): the `AGENTS.md` pointers resolve `../hub` with no network.
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
