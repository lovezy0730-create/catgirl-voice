# 猫娘桌宠（Godot）

一个透明、置顶、无边框的小桌宠，用的是本仓库原创的猫娘立绘。

## 运行

用 Godot 4.7 或更高版本打开本目录，或者直接命令行启动：

```sh
"D:\Godot_v4.7.1-stable_win64.exe" --path <本目录路径>
```

第一次启动时 Godot 会先导入 `character/catgirl_default/mascot.svg`，导入完成后窗口才会显示立绘。

## 操作

| 操作 | 效果 |
| --- | --- |
| 左键按住拖动 | 移动桌宠窗口 |
| 左键双击 | 让猫娘说一句随机台词 |
| 右键单击 | 退出 |
| 等待 7~15 秒 | 猫娘自己说一句话，3.5 秒后淡出 |

鼠标点击会穿透立绘以外的区域，`main.gd` 用拖拽区域的矩形算出 `DisplayServer.window_set_mouse_passthrough` 的命中范围。

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
