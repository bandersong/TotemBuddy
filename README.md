# TotemBuddy

A resto-shaman totem manager for **WoW TBC Classic (Anniversary Edition, Interface 20505)**.

TotemBuddy lets you save named **totem sets** and swap between them — instantly out of combat, or with a bound key mid-fight — plus a one-click **quick-react bar** for reactive utility totems (Grounding, Tremor, cleansing). On top of that it keeps the streamlined totem bar, hover popups, timers, weapon-buff buttons, and Reincarnation tracking from its parent addon.

> **Attribution:** TotemBuddy is a fork of [TotemDeck](https://github.com/iltGames/TotemDeck) by iltGames, used under the MIT License. The original copyright is retained in [LICENSE](LICENSE). See [DESIGN.md](DESIGN.md) for architecture and the rules that shaped it.

---

## Installation

1. Copy the `TotemBuddy` folder into `World of Warcraft/_classic_/Interface/AddOns/`.
   - **Git users:** `cd` into `Interface/AddOns/` and `git clone https://github.com/bandersong/TotemBuddy.git`, then `git pull` to update.
2. Restart WoW or type `/reload`.
3. The bar appears automatically on Shaman characters.

---

## Totem Sets

A **set** is a saved snapshot of your four active totems (one per element). Set your totems the way you like, name the set, and recall it anytime.

**Manage sets in the UI:** `/tb config` → **Sets** tab
- **Save current totems as:** type a name, click **Save**
- Per set row: **Apply** · **Rename** · **Del** · **↑ ↓** (reorder) · **Bind**
- The active set's name is shown in **green**

**Or from chat:**

| Command | Description |
|---------|-------------|
| `/tb saveset <name>` | Save current totems as a named set |
| `/tb sets` | List saved sets |
| `/tb set <name>` | Apply a saved set (case-insensitive) |
| `/tb delset <name>` | Delete a saved set |

### Switching sets in combat (the legal way)

You **cannot** drop a whole set with one keypress — Blizzard's policy is **one keypress = one cast** (see [DESIGN.md](DESIGN.md)). TotemBuddy works *with* that rule:

- Click **Bind** on a set and press a key chord (e.g. `Shift-1`). That key casts the set's `/castsequence`: **press it repeatedly to drop the set, one totem per press.**
- To switch sets mid-fight, press a **different** set's bound key. No menus, no automation — fully ToS-clean.
- Out of combat, **Apply** swaps the whole set at once and rebuilds your cast macro. In combat, Apply queues and takes effect the moment you leave combat.

---

## Quick-React Bar

A small, movable bar of one-click utility totems for reactive drops. Defaults: **Grounding, Tremor, Poison Cleansing, Disease Cleansing, Earthbind**.

| Command | Description |
|---------|-------------|
| `/tb quick` | Toggle the quick-react bar |
| `/tb quick config` | Open the quick-react settings window |

In the settings window you can show/hide the bar, **add** a totem (by name or spell ID), **remove** one, and **bind a key** to each. **Ctrl+drag** the bar to move it. Each button casts exactly one totem per click or keypress.

---

## Totem Bar, Timers, Weapon Buffs, Reincarnation

| Feature | Notes |
|---------|-------|
| **4-element bar** | Earth / Fire / Water / Air, with a hover popup of every trained totem per element |
| **Click behaviour** | Left-click casts the active totem; right-click sets active / dismisses; Shift+right-click = Totemic Call (recall) |
| **Timers** | Bar or icon style, positioned above/below/left/right; per-element expiry sounds |
| **Out-of-range dim** | Icons dim when you leave the radius of a buff totem (Windfury, Strength of Earth, Mana Spring, resistances, …) |
| **Weapon buffs** | One-button access to Rockbiter/Flametongue/Frostbrand/Windfury; left=main hand, right=off-hand |
| **Reincarnation** | Ankh count + cooldown sweep; green when ready, red when out of Ankhs |

### Generated macros

TotemBuddy maintains these account macros (toggle them in **Config → Macros**):

| Macro | Description |
|-------|-------------|
| `TBEarth` / `TBFire` / `TBWater` / `TBAir` | Cast the active totem for that element |
| `TBAll` | `/castsequence` of all four active totems (press repeatedly to drop them in order) |

---

## All Commands

| Command | Description |
|---------|-------------|
| `/tb` | Show help |
| `/tb config` | Open the config window |
| `/tb show` | Toggle bar visibility |
| `/tb timers` | Toggle timer display |
| `/tb timers above\|below\|left\|right` | Set timer position |
| `/tb popup up\|down\|left\|right` | Set popup direction |
| `/tb macros` | Recreate the generated macros |
| `/tb sets` | List saved sets |
| `/tb saveset <name>` | Save current totems as a set |
| `/tb set <name>` | Apply a saved set |
| `/tb delset <name>` | Delete a saved set |
| `/tb quick` | Toggle the quick-react bar |
| `/tb quick config` | Open quick-react settings |

### Combat note
Blizzard locks secure actions (casting setup, macro edits, keybindings, hiding frames) during combat. TotemBuddy queues any such change and applies it automatically when you leave combat. Popup bars stay clickable in place rather than vanishing mid-fight — enable **Always Show Popup** to avoid accidental clicks.

---

## License

MIT — see [LICENSE](LICENSE). Original work © the TotemDeck authors; fork modifications under the same license.
