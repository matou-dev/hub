---
type: spec
status: active
maturity: prototype
scope: shared
roadmap: -
---

# Item Registration — MatouItem, ItemSpec and Loot Gem

Date: 2026-09-11
Status: active

## Problem

In [`decisions/LOOT.md`](LOOT.md#L187-L192), the loot drops for harvested ore
and killed beasts landed as a placeholder `Items.diamond` item carrier. The
declared content in `owned.matou` specifies `item my_gem (stack = 64, label = "shiny")`
and `drop = example1.content:my_gem`. Without an item registration mechanism,
custom items cannot exist in the Minecraft item registry, forcing drops to rely
on hardcoded vanilla placeholder items.

## Decision

1. **ItemSpec (Pure Java 8, zero MC)**:
   In `example1`, `ItemSpec` parses `genre Item : Data` (`stack: u32`, `label: string`)
   from content files (e.g. `content/owned.matou`). Refusals are loud and explicit
   with `E_EXAMPLE_ITEMSPEC:*`.

2. **MatouItem (Forge)**:
   A generic item class extending `net.minecraft.item.Item` that sets the unlocalized
   name and max stack size (`setMaxStackSize`).

3. **Item Registration Seam**:
   - In `Example1Mod` (modid `example1`), during `preInit`, any items declared in
     the content file referenced by `ownedFile` are registered via
     `GameRegistry.registerItem(new MatouItem(...), shortName)`.
   - During `init`, registration is verified via `GameRegistry.findItem("example1", shortName)`
     and announced: `[MatouBridge] registered-item <example1:my_gem> id <ID>`.
   - Refusal errors on item registration use `E_REG_ITEM:*`.

4. **Loot Table Gem Resolution**:
   - In `MatouBridgeMod.wireLoot`, instead of checking `Items.diamond`, the bridge
     resolves the drop items defined in the loot table (`policy.lootDrops()`)
     through the Forge item registry.
   - If an item is unresolvable, the bridge fails fast with `E_LOOT_ITEM:unknown <item>`.
   - In `dropCarrier`, the spawned `EntityItem` carries the resolved `Item`:
     `new ItemStack(resolvedItem, 1)`.

5. **Parity Across Bridges**:
   - `MatouItem.java` is introduced in `bridge-1710/forge/src/fr/iamacat/bridge/forge/`.
   - Parity shells pointing at `decisions/ITEM_REGISTRATION.md` are added to
     `bridge-1122`, `bridge-1165`, and `bridge-1201` to maintain identical Forge
     file sets.
   - The queue row in `decisions/BRIDGE_PARITY.md` tracks the port across bridges.

## Refusal Catalog

- `E_EXAMPLE_ITEMSPEC:null namespace`
- `E_EXAMPLE_ITEMSPEC:null name`
- `E_EXAMPLE_ITEMSPEC:bad name <>`
- `E_EXAMPLE_ITEMSPEC:bad stack <stack> for <name> (1..64)`
- `E_EXAMPLE_ITEMSPEC:null label for <name>`
- `E_EXAMPLE_ITEMSPEC:null path`
- `E_EXAMPLE_ITEMSPEC:unreadable <path>`
- `E_EXAMPLE_ITEMSPEC:bad namespace in <path>`
- `E_EXAMPLE_ITEMSPEC:bad shape in <path>`
- `E_EXAMPLE_ITEMSPEC:bad instance in <path>`
- `E_EXAMPLE_ITEMSPEC:bad name in <path>`
- `E_EXAMPLE_ITEMSPEC:bad fields <name> in <path>`
- `E_EXAMPLE_ITEMSPEC:bad stack <name> in <path>`
- `E_EXAMPLE_ITEMSPEC:bad label <name> in <path>`
- `E_REG_ITEM:already registered <item>`
- `E_REG_ITEM:no ownedFile for <item>`
- `E_REG_ITEM:no item <name> in <ownedFile>`
- `E_REG_ITEM:refused <item>`
- `E_REG_ITEM:unresolved <item>`
- `E_LOOT_ITEM:unknown <item>`
