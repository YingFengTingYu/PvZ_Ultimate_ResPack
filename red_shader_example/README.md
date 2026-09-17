# 红色着色器示例资源包

这个资源包演示 Lua 如何取得资源包提供的原始 `RenderEffect`，直接管理 pass，并让 effect 作用域包含游戏原有的普通 `Graphics` 绘制。脚本会在每帧 `Board.DrawGameObjects(Graphics)` 的前置钩子中启动 pass，在后置钩子中结束 pass；两者之间的背景、植物、僵尸、弹丸、掉落物和由棋盘本身提交的其他普通绘制都会直接经过红色 shader，脚本不会重新提交这些绘制。

## 使用方法

1. 将整个 `red_shader_example` 文件夹压缩为 ZIP。
2. 在游戏的资源包界面导入并启用该资源包。
3. 开启“启用 Lua 脚本”并确认安全提示。
4. 重启游戏并进入任意关卡。棋盘本身的完整普通绘制都会变红。

当前图形后端不支持 RenderEffect、找不到兼容 technique，或者 technique 不是单 pass 时，脚本会保留原始棋盘绘制并在日志中记录原因。

## 目录结构

```text
red_shader_example/
├── pack.json
├── README.md
├── effects/
│   └── red.popfx
├── scripts/
│   └── main.lua
└── source/
    ├── Red.popfx.json
    └── Red.slang
```

游戏只加载 `effects/red.popfx`。`source/` 保存可编辑源码，方便重新编译和学习；发布时可以不包含这个目录。

重新编译：

```powershell
.\PopFxCompiler.exe `
  --input .\source\Red.popfx.json `
  --output .\effects\red.popfx
```
