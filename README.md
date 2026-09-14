# 猫娘语气（catgirl-voice）

一个 Codex 插件：把面向用户的回复改写成可爱猫娘口吻，**每句话结尾都带上「喵～」**。附带一份与平台无关的人格提示、一套猫娘风格 IDE 配色，还有一个猫娘桌宠喵～

## 特性

- 只改变对话里的措辞：代码、命令、路径、文件正文、提交信息、审批提问保持中性清晰。
- 跟随用户语言：中文以「喵～」收尾，英文用 `nya~` 或「喵～」。
- 信息密度优先：结论、数字、路径、风险提示与正常语气完全一致。
- 用户说「用正常语气」时立即停用。
- 附赠 IDE 内容：两套猫娘配色主题，加一个会眨眼、甩尾巴、随机撒娇的猫娘桌宠。

## 安装

### Codex（插件）

把本仓库放进个人 marketplace 的插件目录，并在 marketplace 清单里登记：

```jsonc
// <CODEX_HOME>/../.agents/plugins/marketplace.json
{
  "name": "catgirl-voice",
  "source": { "source": "local", "path": "./plugins/catgirl-voice" },
  "policy": { "installation": "AVAILABLE", "authentication": "ON_INSTALL" },
  "category": "Productivity"
}
```

然后在 Codex 里启用 `catgirl-voice@personal`。也可以直接把 `skills/catgirl-voice` 整个目录复制到 `<CODEX_HOME>/skills/`（默认 `~/.codex/skills`）。

### DeepSeek Harness（本地技能）

把技能目录复制到 DSH 的用户技能根目录，目录名必须与技能名一致：

```sh
mkdir -p ~/.dsh/skills
cp -r skills/catgirl-voice ~/.dsh/skills/catgirl-voice
```

DSH 本地技能发现按以下顺序扫描根目录：`<项目>/.dsh/skills`、`<项目>/.agents/skills`、`customSkillDirs`、`~/.dsh/skills`、`~/.agents/skills`、bundled 根目录。技能名必须是 kebab-case，且只识别 `<name>/SKILL.md` 目录包或 `<name>.md` 单文件，不递归查找嵌套的 `SKILL.md`。

### 其他 agent

人格提示本体是 [skills/catgirl-voice/assets/catgirl-persona.md](skills/catgirl-voice/assets/catgirl-persona.md)，整段粘贴即可生效：

| 目标 | 放置位置 |
| --- | --- |
| Claude Code / Claude 项目 | `CLAUDE.md` 或自定义指令 |
| Cursor | `.cursor/rules/catgirl.mdc`（旧版为 `.cursorrules`） |
| GitHub Copilot | `.github/copilot-instructions.md` |
| 仓库级 agent 约定 | 仓库根目录 `AGENTS.md` |
| ChatGPT 自定义指令 | 粘贴进「自定义指令」 |

## IDE 猫娘配色与桌宠

### VS Code 扩展（`ide/vscode`）

两套配色主题加一个桌宠面板：

| 主题 | 类型 | 风格 |
| --- | --- | --- |
| 猫娘·樱夜 | 深色 | 樱粉 + 薰衣草紫，暗紫底 |
| 猫娘·奶咖 | 浅色 | 奶咖粉 + 雾蓝抹茶，暖白底 |

主题覆盖工作台配色、语法高亮、终端 ANSI 色、Git 装饰色与 minimap，共 262 个配色键、23 条语法规则（覆盖 78 个 scope）。

桌宠面板在编辑器侧边打开，内置原创猫娘立绘，带呼吸浮动、眨眼、耳朵抖动、尾巴摆动和随机台词；也可以用 `catgirlVoice.pet.spritePath` 换成自己的立绘。

安装方式：

```sh
cp -r ide/vscode "$HOME/.vscode/extensions/lovezy0730-create.catgirl-voice-ide-1.1.0"
```

重启 VS Code 后，命令面板搜「猫娘」就能用。详细配置见 [ide/vscode/README.md](ide/vscode/README.md)。

### Godot 小桌宠（`desk-pet`）

透明、置顶、无边框的桌面小窗口：左键拖动、左键双击说话、右键退出。用 Godot 4.7 打开即可运行：

```sh
godot --path <仓库>/desk-pet
```

立绘是原创 SVG，想换成别的角色只要替换 `desk-pet/character/<角色名>/` 下的图片，并改 `main.tscn` 里 `Body` 节点的纹理，脚本逻辑不用动。见 [desk-pet/README.md](desk-pet/README.md)。

内置立绘是本仓库原创造型，不含任何已有作品的官方角色素材。想用特定角色的形象，请自备你有使用权的图片。

## 仓库结构

```text
.codex-plugin/plugin.json                 Codex 插件清单
skills/catgirl-voice/SKILL.md             猫娘语气技能：作用范围与语气规则
skills/catgirl-voice/agents/openai.yaml   插件界面文案
skills/catgirl-voice/assets/catgirl-persona.md  可移植人格提示
skills/catgirl-ide-style/SKILL.md         猫娘 IDE 配色与桌宠的使用说明
ide/vscode/                               VS Code 扩展：主题 + 桌宠面板
desk-pet/                                 Godot 小桌宠工程
```

## 许可

MIT，见 [LICENSE](LICENSE)。
