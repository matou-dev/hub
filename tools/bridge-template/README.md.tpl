# matou-dev/bridge-@SFX@ — SPI ↔ Minecraft @MC@ translator

The only module allowed to touch MC/Forge @MC@ (Forge @FORGE@) on
this side. Translates `matou-spi` into the game (world, registries).

Modid: `matoubridge` (see hub `NAMES.md` — reused from the other bridges,
safe: two bridges never load in the same MC instance).

The decide/apply seam (`fr.iamacat.bridge`: `SpiBridge`, `CellSink`,
`ForgeCells`, `ForgeSnapshot`, `ForgeContent`, `Packs`) ships from
`matou-spi` (see `SPI_PIN`) at identical FQNs — this repo carries only its
Forge side below. Pure coverage lives in SPI (`BridgeCheck`); content E2E
(`ForgeContentCheck` against `../example1`) is wired in @P2@ below.

## @P1@ Forge wiring (Forge @FORGE@)

Only `forge/` touches MC/Forge (@SINK_DESC@,
overworld y `0..@MAX_Y@`):

- `forge/src/fr/iamacat/bridge/forge`: `MatouBridgeMod`
  (`@Mod(modid="matoubridge")`, FML server tick `END` dim 0 → snapshot
  `matou:tick` → pure decide), `PackWire` (reflective bind + block
  resolve + y check, fail fast), `WorldCellSink` (`CellSink` into the
  world, volume cells resolve their block by name, cached, unknown refused
  loudly). Passive until `packs.cfg` exists (Q1 coexistence).
- `tools/live/stub`: shape-only @MC@ API used by `forge/` (compile
  classpath only, never runs). Etage 2 compiles `forge/` against it —
  green with no MC jars. `run-live.sh` (@P3@) asserts these members
  against the provisioned @FORGE_LONG@ jars once wired.

Gate: `tools/check.sh` (etage 1 siblings-spi-ex1 compile + pure E2E,
etage 2 forge-vs-stub compile, etage 3 `LIVE=1` runs `tools/run-live.sh`).

## @P2@ content wiring (packs)

Packs come from `config/matoubridge/packs.cfg`
(`<class> <y> <block> [k=v ...]`, `#` comments, missing file = passive
like @P1@). Contract in `matou-spi` (`ContentPack` + optional
`ConfigurablePack` for operator args, `ForgeContent` for decide +
apply), `Packs` (strict config parse + reflective `load`) from the
shared seam, E2E `java/test/.../ForgeContentCheck` (real example1 jobs
from the source files + fake world; `ForgeContent.merge ==
AdditiveScatterJob.merge` comparator). Body kept in sync with the other
bridges by convention.

## @P3@ live proof (TODO)

`tools/run-live.sh` is a scaffold placeholder that fails loudly until the
live run is ported from bridge-@REF_SFX@ (pins, mapping, server boot,
world==union verify). See the placeholder header for the port checklist.
