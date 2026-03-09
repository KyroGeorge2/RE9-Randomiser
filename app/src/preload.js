const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  detectGamePath:  ()               => ipcRenderer.invoke('detect-game-path'),
  browseGamePath:  ()               => ipcRenderer.invoke('browse-game-path'),
  writeSeed:       (args)           => ipcRenderer.invoke('write-seed',        args),
  installLuaMod:   (args)           => ipcRenderer.invoke('install-lua-mod',   args),
  openFolder:      (args)           => ipcRenderer.invoke('open-folder',       args),
  checkReframework:(args)           => ipcRenderer.invoke('check-reframework', args),
  readFile:        (args)           => ipcRenderer.invoke('read-file',         args),
  getStatsPath:    (args)           => ipcRenderer.invoke('get-stats-path',    args),
})
