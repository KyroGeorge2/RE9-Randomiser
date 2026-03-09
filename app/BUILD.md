# RE9 Item Randomiser — Build Instructions

## Prerequisites
- Node.js 18+ (https://nodejs.org)
- npm (comes with Node)
- Windows or a machine that can target Windows builds

## Build steps

```bash
# 1. Install dependencies (only needed once)
npm install

# 2. Build the Windows exe
npm run build
```

The output will be in the `dist/` folder:
- `RE9-Randomiser-Portable.exe` — single-file portable exe, no install needed
- `RE9 Item Randomiser Setup.exe` — installer version

## What to ship on Nexus Mods

Upload both files from `dist/`:
- The portable `.exe` for users who want drag-and-drop
- The installer `.exe` for users who prefer it

**The Lua mod is bundled inside the exe** (from `assets/re9_randomiser.lua`).  
Users click "Install Lua Mod to Game" inside the app and it copies it automatically.

## Development

```bash
npm start   # Run without building (shows the app live)
```

## Folder structure

```
re9-randomiser-app/
├── src/
│   ├── main.js        ← Electron main process (path detection, file writing)
│   ├── preload.js     ← Secure bridge between UI and Node
│   └── index.html     ← The randomiser UI (your existing HTML)
├── assets/
│   ├── re9_randomiser.lua   ← Lua mod bundled into the exe
│   └── icon.ico             ← App icon (replace with your own 256x256 .ico)
└── package.json
```

## Icon

Replace `assets/icon.ico` with a 256x256 .ico file before building.
You can convert a PNG at https://convertio.co/png-ico/
