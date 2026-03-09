# RE9 Item Randomiser
A real-time item randomiser for **Resident Evil 9: Requiem** using REFramework.

Every item pickup is swapped to something random — ammo becomes herbs, herbs become grenades, the occasional weapon surprise. Fully seeded, reproducible, and now with live race mode.

---

## ⬇️ Download
Grab the latest release from the [Releases](../../releases) page:
- **`RE9-Randomiser-Portable.exe`** — Windows desktop app (auto-detects game, installs mod in one click)
- Or use the seed generator directly: open `re9-randomiser.html` in any browser, no install needed

---

## 🚀 Quick Start

### Using the Desktop App (recommended)
1. Install [REFramework](https://github.com/praydog/REFramework) for RE9 first
2. Download `RE9-Randomiser-Portable.exe` from [Releases](../../releases)
3. It auto-detects your RE9 Steam install
4. Click **Install Lua Mod** to copy the mod into your game folder
5. Set a seed, click **Generate + Export Seed**
6. Launch RE9 — the mod loads automatically via REFramework

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
| Ammo, consumables & ink ribbons | **Always random** on every pickup — different result each time |
| Weapons | ~15% chance as a random drop, no duplicates per run |
| Key items from drops | Deduplicated — you won't receive the same key item twice |
| Ghost / `?` items | Fully blacklisted — will never appear |
| Blood collectors, flashlight, starting weapons | Protected — never randomised |

> ⚠️ **Avoid using the Item Box during a randomiser run.** Items taken from the box will be randomised.

---

## ⚡ Race Mode

Challenge friends to a real-time race on the same seed.

1. Both players open the **Race Mode** tab in the app
2. Host creates a lobby, sets a seed and game difficulty, shares the 6-character code
3. Joiner enters the code
4. Both players click **Ready Up** — a 3-second countdown triggers automatically
5. Race timer starts in the app — play through the game
6. Deaths sync live from the REFramework mod every 5 seconds
7. First to finish clicks **Finish** — the other player approves or disputes the time
8. Approved runs are submitted to the **Global Leaderboard**

### Global Leaderboard
- View all approved finishes across every player
- Sorted by time, filterable by difficulty
- Colour coded: 🔴 Insanity · 🟡 Standard (Classic) · 🟢 Standard (Modern) · 🔵 Casual

---

## Building the Desktop App

Requirements: [Node.js](https://nodejs.org) 18+

```bash
cd app
npm install
npm run build
```

Built exe appears in `app/dist/`.

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
| `it70_` | Weapon parts (never randomised) |
| `it99_` | Special items (ink ribbons, trackers, blood collectors) |

---

## Roadmap

- [x] Real-time item swapping via REFramework hook (`app.Inventory.mergeOrAdd`)
- [x] Seeded RNG — reproducible runs per seed + run number
- [x] Consumables re-randomise every pickup
- [x] Weapon drop rate cap (~15%)
- [x] No duplicate weapons or key items per run
- [x] Ghost/placeholder item blacklist
- [x] Character compatibility check (Grace-only / Leon-only items)
- [x] Race mode — private lobbies, live leaderboard, ready-up countdown
- [x] Death tracking via REFramework hook
- [x] Global leaderboard with difficulty tags
- [x] Finish confirmation with opponent approval
- [ ] Progression item location shuffling (scene-aware)
- [ ] Per-item quantity tuning
- [ ] Co-op / multiplayer support

---

## Requirements
- Resident Evil 9: Requiem (Steam)
- [REFramework](https://github.com/praydog/REFramework) for RE9
- Internet connection for Race Mode (offline play works without it)

---

## 🐛 Bug Reports
Found a bug? [Open an issue on GitHub](../../issues) — include the item ID from the Recent Swaps panel if it's item-related.

---

## Contributing
PRs welcome. If you find a `?` ghost item appearing or hit a softlock, open an issue with the item ID shown in the **Recent Swaps** panel in the REFramework overlay.
