# 角色立绘槽位

`catgirl_default/` 是本仓库原创的猫娘立绘，不是任何已有作品的官方角色形象。

## 目录约定

每个角色一个目录，里面按固定文件名放立绘：

```text
character/<角色名>/
├── base.png         主立绘（睁眼），必需
├── eyes_half.png    半睁眼叠图，可选
└── eyes_closed.png  闭眼叠图，可选
```

`main.gd` 顶部的 `CHARACTER_DIR` 决定当前用哪个目录，默认指向 `res://character/elaina_catgirl`。目录里没有 `base.png` 时，桌宠继续用场景自带的 `catgirl_default/mascot.svg`，空目录不会报错。

`eyes_half.png` 与 `eyes_closed.png` 同时存在时自动开启眨眼：半睁 → 闭 → 半睁 → 睁，间隔 3~8 秒随机。

## 叠图要求

叠图必须与 `base.png` **同画布尺寸、同构图、同透明区域**，只在眼睛区域不同。这样 `main.gd` 才能用同一个缩放和同一个位置把两张图叠起来，否则眨眼会错位。

## 立绘要求

- 透明背景 PNG 或 SVG。
- 角色居中，画面底部留一点空间，方便呼吸浮动动画。
- 立绘按高度自适应缩放到 236 px，所以 1024×1024 这类大图可以直接用。
- 想换台词或改拖动方式，编辑 `main.gd` 顶部的 `SPEECH_LINES` 与输入处理函数即可。

## 同人素材提示

换成其他作品的角色立绘时，请使用你有使用权的图片，并让素材只留在本地：`.gitignore` 已忽略 `desk-pet/character/` 下除 `catgirl_default/` 以外的目录，所以放在这里的同人图不会被提交，也不会推到公开仓库。
