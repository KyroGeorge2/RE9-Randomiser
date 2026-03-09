const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron')
const path  = require('path')
const fs    = require('fs')
const os    = require('os')

// ── Steam / RE9 path detection ────────────────────────────────
const RE9_STEAM_ID  = '2959330'
const RE9_FOLDER    = 'RESIDENT EVIL requiem BIOHAZARD requiem'
const SEED_REL_PATH = path.join('reframework', 'data', 're9_randomiser', 'seed.json')
const LUA_REL_PATH  = path.join('reframework', 'autorun', 're9_randomiser.lua')

function findSteamLibraries () {
  const candidates = []

  if (process.platform === 'win32') {
    // Default Steam install locations
    const drives = ['C', 'D', 'E', 'F', 'G']
    for (const d of drives) {
      candidates.push(`${d}:\\Program Files (x86)\\Steam`)
      candidates.push(`${d}:\\Steam`)
      candidates.push(`${d}:\\SteamLibrary`)
      candidates.push(`${d}:\\Games\\Steam`)
    }

    // Read SteamApps library folders from registry (via libraryfolders.vdf)
    const appData = process.env.LOCALAPPDATA || ''
    const steamReg = [
      path.join(appData, '..', 'Roaming', 'Valve', 'Steam'),
      'C:\\Program Files (x86)\\Steam',
    ]
    for (const steamBase of steamReg) {
      const vdf = path.join(steamBase, 'steamapps', 'libraryfolders.vdf')
      if (fs.existsSync(vdf)) {
        const text = fs.readFileSync(vdf, 'utf8')
        const matches = [...text.matchAll(/"path"\s+"([^"]+)"/g)]
        for (const m of matches) candidates.push(m[1].replace(/\\\\/g, '\\'))
      }
    }
  }

  return [...new Set(candidates)]
}

function detectRE9Path () {
  const libraries = findSteamLibraries()

  for (const lib of libraries) {
    // Check by folder name
    const byName = path.join(lib, 'steamapps', 'common', RE9_FOLDER)
    if (fs.existsSync(byName)) return byName

    // Check appmanifest
    const manifest = path.join(lib, 'steamapps', `appmanifest_${RE9_STEAM_ID}.acf`)
    if (fs.existsSync(manifest)) {
      const text = fs.readFileSync(manifest, 'utf8')
      const m = text.match(/"installdir"\s+"([^"]+)"/)
      if (m) {
        const gamePath = path.join(lib, 'steamapps', 'common', m[1])
        if (fs.existsSync(gamePath)) return gamePath
      }
    }
  }

  return null
}

// ── Window ────────────────────────────────────────────────────
let mainWindow

function createWindow () {
  mainWindow = new BrowserWindow({
    width:  1200,
    height: 820,
    minWidth:  900,
    minHeight: 600,
    title: 'RE9 Item Randomiser',
    backgroundColor: '#0a0a0f',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration:  false,
    },
    // No default menu bar
    autoHideMenuBar: true,
  })

  mainWindow.loadFile(path.join(__dirname, 'index.html'))

  // Open external links in browser not app
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url)
    return { action: 'deny' }
  })
}

app.whenReady().then(createWindow)
app.on('window-all-closed', () => app.quit())
app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow() })

// ── IPC: detect game path ─────────────────────────────────────
ipcMain.handle('detect-game-path', () => {
  return detectRE9Path()
})

// ── IPC: browse for game folder ───────────────────────────────
ipcMain.handle('browse-game-path', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: 'Select RE9 Game Folder',
    properties: ['openDirectory'],
    buttonLabel: 'Select Game Folder',
  })
  if (result.canceled || !result.filePaths.length) return null
  return result.filePaths[0]
})

// ── IPC: write seed.json to game folder ──────────────────────
ipcMain.handle('write-seed', async (event, { gamePath, seedJson }) => {
  try {
    const seedPath = path.join(gamePath, SEED_REL_PATH)
    const seedDir  = path.dirname(seedPath)

    if (!fs.existsSync(seedDir)) {
      fs.mkdirSync(seedDir, { recursive: true })
    }

    fs.writeFileSync(seedPath, seedJson, 'utf8')
    return { ok: true, path: seedPath }
  } catch (err) {
    return { ok: false, error: err.message }
  }
})

// ── IPC: install lua mod ──────────────────────────────────────
ipcMain.handle('install-lua-mod', async (event, { gamePath }) => {
  try {
    const luaDest = path.join(gamePath, LUA_REL_PATH)
    const luaDir  = path.dirname(luaDest)
    const luaSrc  = path.join(__dirname, '..', 'assets', 're9_randomiser.lua')

    if (!fs.existsSync(luaSrc)) {
      return { ok: false, error: 'Lua mod file not found in app assets.' }
    }
    if (!fs.existsSync(luaDir)) {
      fs.mkdirSync(luaDir, { recursive: true })
    }

    fs.copyFileSync(luaSrc, luaDest)
    return { ok: true, path: luaDest }
  } catch (err) {
    return { ok: false, error: err.message }
  }
})

// ── IPC: open folder in explorer ─────────────────────────────
ipcMain.handle('open-folder', async (event, { folderPath }) => {
  shell.openPath(folderPath)
  return true
})

// ── IPC: check if REFramework is installed ───────────────────
ipcMain.handle('check-reframework', async (event, { gamePath }) => {
  const rfPath = path.join(gamePath, 'reframework')
  return fs.existsSync(rfPath)
})
