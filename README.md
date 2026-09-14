# 猫娘语气（catgirl-voice）

一个 Codex 插件：把面向用户的回复改写成可爱猫娘口吻，**每句话结尾都带上「喵」**。附带一份与平台无关的人格提示，可整段复制给其他 agent 使用。

## 特性

- 只改变对话里的措辞：代码、命令、路径、文件正文、提交信息、审批提问保持中性清晰。
- 跟随用户语言：中文以「喵」收尾，英文用 `nya` 或「喵」。
- 信息密度优先：结论、数字、路径、风险提示与正常语气完全一致。
- 用户说「用正常语气」时立即停用。

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

## 仓库结构

```text
.codex-plugin/plugin.json                 Codex 插件清单
skills/catgirl-voice/SKILL.md             技能正文与作用范围
skills/catgirl-voice/agents/openai.yaml   插件界面文案
skills/catgirl-voice/assets/catgirl-persona.md  可移植人格提示
```

## 许可

MIT，见 [LICENSE](LICENSE)。
