---
name: catgirl-ide-style
description: "把编辑器换成猫娘风格：安装并应用「猫娘·樱夜」或「猫娘·奶咖」VS Code 配色，打开猫娘桌宠面板，或运行 Godot 小桌宠。当用户要求给 IDE 换猫娘 / 粉色 / 可爱配色、要猫娘桌宠、要把某个角色做成桌宠立绘时使用。"
---

# 猫娘风格 IDE

这个技能对应仓库里的两份产物，路径都相对于仓库根目录喵～

| 产物 | 路径 | 说明 |
| --- | --- | --- |
| VS Code 扩展 | `ide/vscode/` | 两套配色主题 + 桌宠 webview 面板 |
| Godot 小桌宠 | `desk-pet/` | 透明置顶桌宠窗口，可换立绘 |

## 安装 VS Code 扩展

把 `ide/vscode` 复制到 VS Code 的扩展目录，重启编辑器即可生效：

```text
%USERPROFILE%\.vscode\extensions\lovezy0730-create.catgirl-voice-ide-<版本>
```

注意：只把文件夹复制进扩展目录，VS Code 不会认它，`extensions.json` 里没有条目就会被忽略。正确做法是打成 `.vsix` 再用 `code --install-extension <file>.vsix --force` 安装。

装好后用命令面板执行：

* `猫娘语气：应用猫娘配色`：按 `catgirlVoice.theme.variant` 切到 `猫娘·樱夜`（深色）或 `猫娘·奶咖`（浅色）。
* `猫娘桌宠：打开面板`：在侧边打开桌宠面板。
* `猫娘桌宠：选择自定义立绘`：换成自己的图片。

## 换成自己的角色立绘

Godot 桌宠与 VS Code 面板用同一套文件命名：

```text
<角色目录>/
├── base.png         主立绘（睁眼），必需
├── eyes_half.png    半睁眼叠图，可选
└── eyes_closed.png  闭眼叠图，可选
```

叠图必须与主立绘同画布、同构图，只在眼睛区域不同，三张齐全时两端都会自动眨眼。

## 运行 Godot 桌宠

```sh
godot --path <仓库>/desk-pet
```

左键拖动、左键双击说话、右键退出。立绘槽位与替换方法见 `desk-pet/character/README.md`。

## 关于角色立绘

内置立绘是仓库原创的猫娘造型。用户想换成某个具体作品的角色时，不要凭空生成或复刻该角色的官方形象；请让用户提供自己拥有使用权的图片，再用「选择自定义立绘」或替换 `desk-pet/character/<角色名>/` 下的文件接入。换角色只需要改 `main.tscn` 里 `Body` 节点的纹理，脚本逻辑不用动。

## 关卡自检

改完主题或场景后，至少确认：

* 主题 JSON 能解析，`colors` 里的值都是 `#RRGGBB` 或 `#RRGGBBAA`。
* `package.json` 里 `contributes.themes` 的路径都指向存在的文件。
* Godot 场景里每个 `ExtResource` 都能在磁盘上找到，`load_steps` 等于资源总数加一。
* `main.tscn` 的连接方法与 `main.gd` 里的 `func` 名称一致。
