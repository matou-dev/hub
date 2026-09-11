#!/bin/sh
# client-prism.sh — Prism instance staging (DEV ONLY).
# SOURCED by hub tools/run-client.sh at the §2 point, never executed.
# Moved verbatim from run-client.sh (ceiling split, same commit — every
# FAIL/ok line keeps its `run-client` tag). Expects, all set before the
# §2 point: PRISM_DIR INST BLD FAT MATOU_MODS HAVE_AUTOPLAY BRIDGE MC NOTE
# + helper live_mod_has_metadata (live-common.sh, sourced in run-client.sh).
# Sets: IDIR GDIR OPT WORLD (exported) OFFLINE_NAME.
# 2. Prism instance (MultiMC format, as proven by local Prism 11 instances:
#    instance.cfg + mmc-pack.json + minecraft/ game dir).
IDIR="$PRISM_DIR/instances/$INST"
mkdir -p "$IDIR/minecraft/mods" "$IDIR/minecraft/config/matoubridge"
# Headless-proof game dir: singleplayer auto-pauses on lost focus, and
# under Xvfb the window never owns the focus — the integrated server then
# stops ticking seconds after join and the automated proof dies by timeout
# (measured on 1122: 1 world tick played, regions untouched after the pause
# flush). Pin pauseOnLostFocus:false (create or amend, never clobber the
# rest of a dev's file).
OPT="$IDIR/minecraft/options.txt"
if [ -f "$OPT" ]; then
  if grep -q "^pauseOnLostFocus:true" "$OPT"; then
    sed -i 's/^pauseOnLostFocus:true/pauseOnLostFocus:false/' "$OPT"
    echo "note run-client : pinned pauseOnLostFocus:false in existing options.txt (headless proof)"
  elif ! grep -q "^pauseOnLostFocus:" "$OPT"; then
    printf 'pauseOnLostFocus:false\n' >> "$OPT"
    echo "note run-client : appended pauseOnLostFocus:false to options.txt (headless proof)"
  fi
else
  printf 'pauseOnLostFocus:false\n' > "$OPT"
  echo "note run-client : seeded options.txt with pauseOnLostFocus:false (headless proof)"
fi
cat > "$IDIR/mmc-pack.json" <<EOF
{
    "components": [
        {
            "cachedName": "Minecraft",
            "important": true,
            "uid": "net.minecraft",
            "version": "$MC"
        },
        {
            "cachedName": "Forge",
            "uid": "net.minecraftforge",
            "version": "$FORGE_COMP"
        }
    ],
    "formatVersion": 1
}
EOF
# Minimal instance.cfg: Prism fills component metadata on first launch.
cat > "$IDIR/instance.cfg" <<EOF
[General]
ConfigVersion=1.3
InstanceType=OneSix
JavaPath=$JAVA_HOME/bin/java
ManagedPack=false
MaxMemAlloc=4096
MinMemAlloc=1024
OverrideJavaLocation=true
OverrideMemory=true
iconKey=default
name=$INST
notes=matou-dev bridge-$SFX dev client (hub run-client.sh; DEV bytes, not release)
EOF
rm -f "$IDIR/minecraft/mods/"*.jar
if [ "$FAT" = "1" ]; then
  # Isolated jars (found live in D3, then E3): only the FAT bridge (spi +
  # example1 embedded above) plus listed mod jars that carry Forge mod
  # metadata. A metadata-less jar here would break the ModLauncher boot,
  # so it fails loudly instead of staging a red instance — minimap has no
  # Forge wrapper yet (pure SPI proof), which is exactly what this names.
  cp "$BLD/jars/matoubridge-reobf.jar" "$IDIR/minecraft/mods/matoubridge.jar"
  for m in $MATOU_MODS; do
    [ "$m" = "example1" ] && continue
    if mod_has_metadata "$BLD/jars/matou-$m.jar"; then
      cp "$BLD/jars/matou-$m.jar" "$IDIR/minecraft/mods/"
      echo "ok run-client : staged mod <$m> (Forge metadata present)"
    else
      echo "FAIL run-client : mod <$m> has no Forge metadata (no mods.toml nor mcmod.info in matou-$m.jar) — FAT era isolates every mods/ jar"
      echo "fix: drop <$m> from MATOU_MODS, or land its Forge wrapper (era metadata + entrypoint) first"; exit 1
    fi
  done
else
  # Flat slim classpath (same 3-jar set the server deploys, plus every
  # listed mod): non-mod jars are inert here, so the whole MATOU_MODS set
  # stages — minimap rides along on 1710/1122 from the same build.
  cp "$BLD/jars/matou-spi.jar" "$BLD/jars/matoubridge-reobf.jar" "$IDIR/minecraft/mods/"
  for m in $MATOU_MODS; do
    cp "$BLD/jars/matou-$m.jar" "$IDIR/minecraft/mods/"
  done
  mv "$IDIR/minecraft/mods/matoubridge-reobf.jar" "$IDIR/minecraft/mods/matoubridge.jar"
  echo "ok run-client : staged mods <$MATOU_MODS> (slim era, flat classpath)"
fi
rm -rf "$IDIR/minecraft/matou-content" && cp -r ../example1/content "$IDIR/minecraft/matou-content"
if [ "${HAVE_AUTOPLAY:-0}" = "1" ]; then
  cp "$BLD/jars/matouautoplay-reobf.jar" "$IDIR/minecraft/mods/matouautoplay.jar"
  echo "ok run-client : autoplay companion staged (DEV-only, never in dist/)"
fi
GDIR="$IDIR/minecraft"
# packs.cfg: written once, then KEPT. Re-staging must never clobber a dev's
# alias bindings (e.g. hut_wall=oak_planks for a varied hut) back to the
# stone proof defaults — that made "whatever happens it's stone".
if [ -f "$IDIR/minecraft/config/matoubridge/packs.cfg" ]; then
  echo "note run-client : keeping existing packs.cfg (delete it to reset to stone proof defaults):"
  grep -v "^#" "$IDIR/minecraft/config/matoubridge/packs.cfg" || true
else
  printf 'fr.iamacat.example1.ExamplePack 63 minecraft:stone ownedFile=%s/matou-content/owned.matou scatterFile=%s/matou-content/additive.matou structureFile=%s/matou-content/structure.matou block.example1.structures:hut_wall=minecraft:stone block.example1.structures:hut_roof=minecraft:stone\n' "$GDIR" "$GDIR" "$GDIR" > "$IDIR/minecraft/config/matoubridge/packs.cfg"
fi
# Beast shape (hub decisions/MATOU_MODEL.md): same keep-or-stage rule as
# packs.cfg — the renderer bakes it and the hitboxes derive from it, so a
# dev hand-tuning the mesh must never lose it to a re-stage.
if [ -f "$IDIR/minecraft/config/matoubridge/my_beast.geo.json" ]; then
  echo "note run-client : keeping existing my_beast.geo.json (delete it to reset to the shipped beast):"
elif [ -f "$BRIDGE/tools/live/my_beast.geo.json" ]; then
  cp "$BRIDGE/tools/live/my_beast.geo.json" "$IDIR/minecraft/config/matoubridge/my_beast.geo.json"
else
  echo "note run-client : no beast geometry shipped by $BRIDGE (shell renderer, nothing to stage)"
fi
WORLD="${AUTOPLAY_WORLD:-matou}"
export AUTOPLAY_WORLD="$WORLD"
OFFLINE_NAME="${OFFLINE_NAME:-MatouDev}"
if [ "${HAVE_AUTOPLAY:-0}" = "1" ]; then
  # Fresh proof every automated run: reset the world, then preseed flat.
  # (Manual varied-hut dev keeps the kept-packs.cfg flow above by running
  # without AUTOPLAY.) Refuses loudly when the save cannot be written.
  python3 tools/autoplay/preseed.py "$GDIR/saves" "$WORLD" \
    || { echo "FAIL run-client : preseed failed"; exit 1; }
fi
if [ -n "${TELLME_JAR:-}" ]; then
  [ -f "$TELLME_JAR" ] || { echo "FAIL run-client : TELLME_JAR=<$TELLME_JAR> absent"; exit 1; }
  if [ -n "${TELLME_SHA1:-}" ]; then
    echo "$TELLME_SHA1  $TELLME_JAR" | sha1sum -c - >/dev/null 2>&1 \
      || { echo "FAIL run-client : TellMe sha1 drift (want $TELLME_SHA1)"; exit 1; }
  fi
  cp "$TELLME_JAR" "$IDIR/minecraft/mods/"
  echo "ok run-client : TellMe installed ($(basename "$TELLME_JAR"))"
else
  echo "note run-client : no TELLME_JAR (bridge only). Runtime inspector suggestion:"
  echo "  TellMe for MC $MC (CurseForge) gives /tellme looking-at|holding|batch-run"
  echo "  for NBT/registry dumps; pin its sha1 in TELLME_SHA1 on first download."
fi
if [ -n "${EXTRA_MODS_DIR:-}" ]; then
  [ -d "$EXTRA_MODS_DIR" ] || { echo "FAIL run-client : EXTRA_MODS_DIR=<$EXTRA_MODS_DIR> absent"; exit 1; }
  if [ -f "$EXTRA_MODS_DIR/SHA256SUMS" ]; then
    (cd "$EXTRA_MODS_DIR" && sha256sum -c SHA256SUMS) \
      || { echo "FAIL run-client : extra mods SHA256SUMS mismatch"; exit 1; }
    echo "ok run-client : extra mods pinned (SHA256SUMS verified)"
  else
    echo "note run-client : no SHA256SUMS in <$EXTRA_MODS_DIR> (unverified copy;"
    echo "  create one with (cd dir && sha256sum *.jar > SHA256SUMS) to pin the bytes)"
  fi
  count=$(ls "$EXTRA_MODS_DIR"/*.jar 2>/dev/null | wc -l)
  [ "$count" -gt 0 ] || { echo "FAIL run-client : no jars in <$EXTRA_MODS_DIR>"; exit 1; }
  cp "$EXTRA_MODS_DIR"/*.jar "$IDIR/minecraft/mods/"
  echo "ok run-client : extra mods installed ($count jars)"
  echo "  dev-only, never in dist/: render/RAM/DFU inspectors for MC $MC."
  echo "  If verify-client-save.sh drifts after adding one, the mod"
  echo "  changed placed blocks: drop it loudly, keep the verdict."
fi
echo "ok run-client : instance staged <$IDIR>"
echo "note run-client : $NOTE"
