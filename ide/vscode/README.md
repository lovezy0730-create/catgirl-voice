# 猫娘语气 IDE（VS Code 扩展）

把猫娘风格带进编辑器：两套配色主题，加一个会说话、会眨眼、会甩尾巴的猫娘桌宠面板。

## 包含内容

- **配色主题**：`猫娘·樱夜`（深色，樱粉 + 薰衣草紫）与 `猫娘·奶咖`（浅色，奶咖粉 + 雾蓝抹茶），覆盖工作台配色、语法高亮、终端 ANSI 色、Git 装饰色与 minimap。
- **猫娘桌宠**：编辑器旁边的 webview 面板，内置原创猫娘立绘，带呼吸浮动、眨眼、耳朵抖动、尾巴摆动与随机台词。
- **自定义立绘**：可以把内置立绘换成自己的图片（png / jpg / webp / gif / svg），见下面的配置说明。

## 快捷键与命令

按 `Ctrl+Shift+P` 打开命令面板，输入「猫娘」：

| 命令 | 作用 |
| --- | --- |
| 猫娘语气：应用猫娘配色 | 按 `catgirlVoice.theme.variant` 切换到对应主题 |
| 猫娘桌宠：打开面板 | 在侧边打开桌宠面板 |
| 猫娘桌宠：选择自定义立绘 | 选一张本地图片作为立绘 |
| 猫娘桌宠：恢复默认立绘 | 换回内置原创立绘 |

## 配置

| 配置项 | 默认值 | 说明 |
| --- | --- | --- |
| `catgirlVoice.theme.variant` | `dark` | `dark` 用樱夜，`light` 用奶咖 |
| `catgirlVoice.pet.enabled` | `true` | 是否启用桌宠命令 |
| `catgirlVoice.pet.spritePath` | 空 | 自定义立绘的本地路径 |
| `catgirlVoice.pet.scale` | `1` | 立绘显示比例，0.3 ~ 3 |
| `catgirlVoice.pet.speechIntervalMs` | `9000` | 自动说话间隔（毫秒） |
| `catgirlVoice.pet.lines` | 内置 6 句 | 桌宠随机台词 |
| `catgirlVoice.pet.statusBar` | `false` | 状态栏是否显示「喵～」入口 |

## 安装

### 从源码安装（本地）

```sh
git clone https://github.com/lovezy0730-create/catgirl-voice.git
```

把 `ide/vscode` 整个目录复制到 VS Code 的扩展目录，然后重启编辑器：

| 平台 | 扩展目录 |
| --- | --- |
| Windows | `%USERPROFILE%\.vscode\extensions\lovezy0730-create.catgirl-voice-ide-1.1.0` |
| macOS / Linux | `~/.vscode/extensions/lovezy0730-create.catgirl-voice-ide-1.1.0` |

也可以在这个目录里用 `vsce package` 打成 `.vsix` 后，通过「从 VSIX 安装」装入。

### 换主题

命令面板 → `Preferences: Color Theme` → 选 `猫娘·樱夜` 或 `猫娘·奶咖`。

## 关于立绘

内置立绘是原创 SVG（`media/mascot.svg`），不是任何已有作品的官方角色形象。想换成特定角色的图片，请用你自己拥有使用权的素材，通过「选择自定义立绘」指定本地文件即可，仓库不会打包这些素材。

## 许可

MIT，见仓库根目录 [LICENSE](../../LICENSE)。
