'use strict'

const fs = require('node:fs')
const path = require('node:path')
const vscode = require('vscode')

const THEME_LABELS = { dark: '猫娘·樱夜', light: '猫娘·奶咖' }

let currentPanel
let statusBarItem

function configuration() {
  return vscode.workspace.getConfiguration('catgirlVoice')
}

function refreshStatusBar(context) {
  const enabled = configuration().get('pet.statusBar', false)
  if (!enabled) {
    statusBarItem?.dispose()
    statusBarItem = undefined
    return
  }
  if (!statusBarItem) {
    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100)
    statusBarItem.command = 'catgirlVoice.openPet'
    statusBarItem.text = '$(heart) 喵～'
    statusBarItem.tooltip = '打开猫娘桌宠面板'
  }
  statusBarItem.show()
  context.subscriptions.push(statusBarItem)
}

function activate(context) {
  context.subscriptions.push(
    vscode.commands.registerCommand('catgirlVoice.applyTheme', async () => {
      const variant = configuration().get('theme.variant', 'dark')
      const label = THEME_LABELS[variant] ?? THEME_LABELS.dark
      await vscode.workspace.getConfiguration('workbench').update('colorTheme', label, vscode.ConfigurationTarget.Global)
      void vscode.window.showInformationMessage(`已经换成「${label}」喵～`)
    }),
    vscode.commands.registerCommand('catgirlVoice.openPet', () => {
      openPetPanel(context)
    }),
    vscode.commands.registerCommand('catgirlVoice.pickSprite', async () => {
      const picked = await vscode.window.showOpenDialog({
        canSelectMany: false,
        openLabel: '用这张立绘',
        filters: { 图片: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg'] }
      })
      if (!picked?.length) return
      const spritePath = picked[0].fsPath
      await configuration().update('pet.spritePath', spritePath, vscode.ConfigurationTarget.Global)
      currentPanel?.dispose()
      openPetPanel(context)
      void vscode.window.showInformationMessage(`桌宠立绘换成 ${spritePath} 了喵～`)
    }),
    vscode.commands.registerCommand('catgirlVoice.resetSprite', async () => {
      await configuration().update('pet.spritePath', '', vscode.ConfigurationTarget.Global)
      currentPanel?.dispose()
      openPetPanel(context)
      void vscode.window.showInformationMessage('桌宠立绘恢复成内置猫娘了喵～')
    }),
    vscode.workspace.onDidChangeConfiguration(event => {
      if (!event.affectsConfiguration('catgirlVoice')) return
      refreshStatusBar(context)
      currentPanel?.dispose()
      currentPanel = undefined
    })
  )
  refreshStatusBar(context)
}

function deactivate() {
  currentPanel?.dispose()
  currentPanel = undefined
}

function openPetPanel(context) {
  if (currentPanel) {
    currentPanel.reveal(vscode.ViewColumn.Beside, true)
    return
  }

  const settings = configuration()
  const spritePath = (settings.get('pet.spritePath', '') || '').trim()
  const panel = vscode.window.createWebviewPanel(
    'catgirlVoicePet',
    '猫娘桌宠',
    { viewColumn: vscode.ViewColumn.Beside, preserveFocus: true },
    {
      enableScripts: true,
      retainContextWhenHidden: true,
      localResourceRoots: [vscode.Uri.joinPath(context.extensionUri, 'media')]
    }
  )
  currentPanel = panel
  panel.onDidDispose(() => {
    if (currentPanel === panel) currentPanel = undefined
  })
  panel.webview.html = renderPetHtml(panel.webview, context.extensionUri, settings, spritePath)
}

function renderPetHtml(webview, extensionUri, settings, spritePath) {
  const nonce = createNonce()
  const mediaRoot = vscode.Uri.joinPath(extensionUri, 'media')
  const styleUri = webview.asWebviewUri(vscode.Uri.joinPath(mediaRoot, 'pet.css'))
  const scriptUri = webview.asWebviewUri(vscode.Uri.joinPath(mediaRoot, 'pet.js'))
  const lines = settings.get('pet.lines', [])
  const scale = clamp(Number(settings.get('pet.scale', 1)) || 1, 0.3, 3)
  const interval = Math.max(2000, Number(settings.get('pet.speechIntervalMs', 9000)) || 9000)

  const customSprite = readCustomSprite(spritePath)
  const figure = customSprite
    ? `<img class="pet-image" src="${customSprite}" alt="自定义猫娘立绘">`
    : inlineMascot()

  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${webview.cspSource} data:; style-src ${webview.cspSource}; script-src 'nonce-${nonce}';">
<link rel="stylesheet" href="${styleUri}">
<title>猫娘桌宠</title>
</head>
<body data-interval="${interval}" data-scale="${scale}">
  <main class="stage">
    <div class="bubble" id="bubble" hidden><span id="bubble-text"></span></div>
    <button class="pet" id="pet" type="button" title="点一下让猫娘说话">
      <span class="pet-figure" id="pet-figure" style="--pet-scale:${scale}">${figure}</span>
    </button>
    <p class="hint">${customSprite ? '当前使用自定义立绘' : '内置原创立绘'} · 点一下猫娘会说话喵～</p>
  </main>
  <script type="application/json" id="catgirl-lines">${escapeForScriptTag(JSON.stringify(lines))}</script>
  <script nonce="${nonce}" src="${scriptUri}"></script>
</body>
</html>`
}

function readCustomSprite(spritePath) {
  if (!spritePath) return undefined
  if (!fs.existsSync(spritePath)) return undefined
  try {
    const extension = path.extname(spritePath).toLowerCase()
    const mime = extension === '.svg' ? 'image/svg+xml' : `image/${extension.replace('.', '') === 'jpg' ? 'jpeg' : extension.replace('.', '')}`
    return `data:${mime};base64,${fs.readFileSync(spritePath).toString('base64')}`
  } catch {
    return undefined
  }
}

function inlineMascot() {
  try {
    const svg = fs.readFileSync(path.join(__dirname, 'media', 'mascot.svg'), 'utf8')
    return svg.replace('<svg ', '<svg class="mascot" ')
  } catch {
    return '<div class="mascot-fallback">喵～</div>'
  }
}

function createNonce() {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  let nonce = ''
  for (let index = 0; index < 32; index += 1) {
    nonce += alphabet[Math.floor(Math.random() * alphabet.length)]
  }
  return nonce
}

function escapeForScriptTag(json) {
  return json.replaceAll('<', '\\u003c').replaceAll('>', '\\u003e').replaceAll('&', '\\u0026')
}

function clamp(value, minimum, maximum) {
  return Math.min(maximum, Math.max(minimum, value))
}

module.exports = { activate, deactivate }
