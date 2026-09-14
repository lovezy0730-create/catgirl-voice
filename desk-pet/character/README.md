# 角色立绘槽位

内置立绘在 `catgirl_default/mascot.svg`，是本仓库原创的猫娘造型，不是任何已有作品的官方角色形象。

## 换成自己的角色

1. 新建一个角色目录，例如 `character/noi_noi/`，把立绘放进去。
2. 让 Godot 导入图片：用 Godot 打开本工程时会自动导入。
3. 打开 `main.tscn`，选中 `CharacterRoot/VisualRoot/Body` 节点，把 `Texture` 换成新立绘。

立绘建议：

- 透明背景的 PNG 或 SVG。
- 角色居中，画面底部留出一点空间，方便呼吸浮动动画。
- 尺寸控制在 400 px 以内，窗口是 360x400，超出会被裁掉。

想换一句话台词或改拖动方式，编辑 `main.gd` 顶部的 `SPEECH_LINES` 与输入处理函数即可。
