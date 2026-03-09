# RE9 Item Randomiser

A real-time item randomiser for **Resident Evil 9: Requiem** using REFramework.

Every item pickup is swapped to something random — ammo becomes herbs, herbs become grenades, the occasional weapon surprise. Fully seeded and reproducible.

---

## ⬇️ Download

Grab the latest release from the [Releases](../../releases) page:
- **`RE9-Randomiser-Portable.exe`** — Windows desktop app (auto-detects game, installs mod in one click)
- Or use the seed generator directly: open `re9-randomiser.html` in any browser, no install needed

---

## 🚀 Quick Start

### Using the Desktop App (recommended)
1. Download `RE9-Randomiser-Portable.exe` from [Releases](../../releases)
2. It auto-detects your RE9 Steam install
3. Click **Install Lua Mod** to copy the mod into your game folder
4. Set a seed, click **Generate + Export Seed**
5. Launch RE9 — the mod loads automatically via REFramework

### Manual Install
1. Install [REFramework](https://github.com/praydog/REFramework) for RE9
2. Copy `re9_randomiser.lua` → `<game>/reframework/autorun/`
3. Open `re9-randomiser.html` in a browser, set your seed, click **Export for Mod**
4. Copy the exported `seed.json` → `<game>/reframework/data/re9_randomiser/seed.json`
5. Launch RE9

---

## How It Works

| Item Type | Behaviour |
|-----------|-----------|
| Key items (`it60_`) | **Never randomised** — always drop as-is to prevent softlocks |
| Ammo & consumables | **Always random** on every pickup — different result each time |
| Weapons | ~15% chance as a random drop, no duplicates per run |
| Key items from drops | Deduplicated — you won't receive the same key item twice |
| Ghost / `?` items | Fully blacklisted — will never appear |

---

## Building the Desktop App

Requirements: [Node.js](https://nodejs.org) 18+

```bash
cd app
npm install
npm run dist
```

Built exe appears in `app/dist/`. Copy it to `releases/` before tagging a GitHub Release.

---

## Item Prefix Reference

| Prefix | Category |
|--------|----------|
| `it00_` | Med Injectors |
| `it10_` | Weapons & Melee |
| `it20_` | Throwables (grenades, bottles) |
| `it40_` | Ammo |
| `it50_` | Crafting materials |
| `it60_` | Key items (never randomised as originals) |
| `it70_` | Weapon parts |
| `it99_` | Special items (trackers, steroids, blood collectors) |

---

## Roadmap

- [x] Real-time item swapping via REFramework hook (`app.Inventory.mergeOrAdd`)
- [x] Seeded RNG — reproducible runs per seed + run number
- [x] Consumables re-randomise every pickup
- [x] Weapon drop rate cap (~15%)
- [x] No duplicate weapons or key items per run
- [x] Ghost/placeholder item blacklist
- [x] Character compatibility check (Grace-only / Leon-only items)
- [ ] Progression item location shuffling (scene-aware)
- [ ] Per-item quantity tuning
- [ ] Co-op / multiplayer support

---

## Requirements

- Resident Evil 9: Requiem (Steam)
- [REFramework](https://github.com/praydog/REFramework) for RE9

---

## Contributing

PRs welcome. If you find a `?` ghost item appearing or hit a softlock, open an issue with the item ID shown in the **Recent Swaps** panel in the REFramework overlay.
