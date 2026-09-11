---
type: spec
status: active
maturity: standard
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
   A generic item class extending `net.minecraft.item.Item` (or `net.minecraft.world.item.Item`
   on 1.20.1) setting version-native unlocalized names and max stack sizes.

3. **Item Registration Seam**:
   - 1.7.10: `GameRegistry.registerItem(new MatouItem(...), shortName)` in `preInit`;
     `init` verifies via `GameRegistry.findItem("example1", shortName)` and announces
     `[MatouBridge] registered-item <example1:my_gem> id <ID>`.
   - 1.12.2: `@SubscribeEvent registerItems(RegistryEvent.Register<Item>)` in
     `@Mod.EventBusSubscriber`; `init` verifies via `Item.getByNameOrId` and announces
     `[MatouBridge] registered-item <example1:my_gem> id <ID>`.
   - 1.16.5: `DeferredRegister<Item>` on mod event bus; common setup verifies via
     `ForgeRegistries.ITEMS.getValue` and announces
     `[MatouBridge] registered-item <example1:my_gem> id <ID>`.
   - 1.20.1: `DeferredRegister<Item>` on mod event bus; common setup verifies via
     `ForgeRegistries.ITEMS.getValue` and announces
     `[MatouBridge] registered-item <example1:my_gem> id <ID>`.
   - Refusal errors on item registration use `E_REG_ITEM:*`.

4. **Loot Table Gem Resolution**:
   - In `MatouBridgeMod.wireLoot`, instead of checking `Items.diamond`, the bridge
     resolves the drop items defined in the loot table (`policy.lootDrops()`)
     through the version-native item registry via `resolveItem(ref)`.
   - If an item is unresolvable, the bridge fails fast with `E_LOOT_ITEM:unknown <item>`.
   - In `dropCarrier`, the spawned carrier entity carries the resolved `Item`:
     `new ItemStack(resolvedItem, 1)`.

5. **Parity Across Bridges**:
   - `MatouItem.java` is version-native across all four bridges:
     `bridge-1710`, `bridge-1122`, `bridge-1165`, and `bridge-1201`.
   - The queue row in `decisions/BRIDGE_PARITY.md` is fully `live` across all 4 bridges.

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
- `E_REG_SHELL:unwired parity shell`
- `E_LOOT_ITEM:unknown <item>`
