# 猫娘桌宠（Godot）

一个透明、置顶、无边框的小桌宠，用的是本仓库原创的猫娘立绘。

## 运行

用 Godot 4.7 或更高版本打开本目录，或者直接命令行启动：

```sh
godot --path <本目录路径>
```

第一次启动时 Godot 会先导入 `character/catgirl_default/mascot.svg`，导入完成后窗口才会显示立绘。

## 操作

| 操作 | 效果 |
| --- | --- |
| 左键按住拖动 | 移动桌宠窗口 |
| 左键双击 | 让猫娘说一句随机台词 |
| 右键单击 | 打开菜单：DeepSeek 余额 / 待办备忘录 / 退出桌宠 |
| 等待 7~15 秒 | 猫娘自己说一句话，3.5 秒后淡出 |

鼠标点击会穿透立绘以外的区域，`main.gd` 用拖拽区域的矩形算出 `DisplayServer.window_set_mouse_passthrough` 的命中范围。

窗口是 480x600，立绘按高度自适应缩放到 420 px。想再大一点，改 `main.gd` 里的 `TARGET_SPRITE_HEIGHT`，同时把 `project.godot` 的窗口尺寸和 `main.tscn` 里的拖拽区域一起调大。

## 右键菜单

菜单只做三件事：

1. **查看 DeepSeek 余额**：请求 `GET https://api.deepseek.com/user/balance`，结果用气泡念出来，余额同时写进菜单项标题，每 10 分钟自动刷新一次。
2. **待办备忘录**：打开 `userdata/todo.md`，没有就先用模板建一份，再用系统默认程序打开（Windows 上一般是记事本或 VS Code）。
3. **退出桌宠**：关掉窗口。

### API Key 从哪来

为了不把密钥写进工程，按这个顺序找：

1. 环境变量 `DEEPSEEK_API_KEY`。
2. `%USERPROFILE%\.codex\config.toml` 里 `deepseek` 分段的 `experimental_bearer_token`，也就是 Codex 自己用的那把 Key。

两个都找不到时余额功能待命，点菜单只会提示去设环境变量。请求只读余额，不做任何写操作。

### 备忘录文件

`userdata/todo.md` 默认带一份模板，属于本地数据，已在 `.gitignore` 里忽略，不会提交也不会推到公开仓库。

## 结构

```text
project.godot    透明、置顶、无边框窗口配置
main.tscn        场景：拖拽区域、立绘、气泡、呼吸动画
main.gd          台词、拖拽、退出、鼠标穿透
character/       立绘槽位，见 character/README.md
icon.svg         工程图标
```

## 换角色

把角色目录放进 `character/<角色名>/`，再改 `main.gd` 顶部的 `CHARACTER_DIR`，场景不用动：

```text
character/<角色名>/
├── base.png         主立绘（睁眼），必需
├── eyes_half.png    半睁眼叠图，可选
└── eyes_closed.png  闭眼叠图，可选
```

三张齐全就自动开启眨眼，只有 `base.png` 就只有呼吸浮动，目录为空则继续用自带的原创立绘。立绘按高度自适应缩放到 236 px，尺寸不限，透明背景即可。叠图必须与主立绘同画布同构图。详细约定见 [character/README.md](character/README.md)。
