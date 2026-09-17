# 示例资源包

这是一个简单的目录式资源包示例，用于演示新版资源包系统的基本用法。

## 包含内容

- `pack.json`：包信息和删除列表
- `images/`：图片资源目录
- `images/popcap_logo.meta.json`：图片属性示例
- `fonts/dwarventodcraft18.meta.json`：投影、彩色轮廓和字面的分层字体示例；自行添加同名 `dwarventodcraft18.ttf` 后生效
- `scripts/main.lua`：自动执行的 Lua 入口脚本
- `README.md`：本说明文件

## 使用方法

1. 添加资源文件到对应目录，例如 `images/`、`sounds/`、`music/`、`fonts/`。
2. 如需指定图片、字体或音效属性，在资源旁边添加 `*.meta.json`。
3. 压缩整个文件夹为 ZIP，例如 `example_pack.zip`。
4. 在游戏资源包界面导入并启用。
5. 如需运行 `scripts/main.lua`，开启列表下方的“启用 Lua 脚本”开关并确认安全提示。
6. 重启游戏。

## ID 推导

资源 ID 根据文件名推导：

- `images/popcap_logo.jpg` -> `IMAGE_POPCAP_LOGO`
- `sounds/chomp.wav` -> `SOUND_CHOMP`
- `fonts/briannetod.ttf` -> `FONT_BRIANNETOD`
- `music/day.ogg` -> `MUSIC_DAY`

如果要覆盖游戏内置资源，文件名需要推导出相同 ID。

## 目录结构

```text
example_pack/
├── pack.json
├── README.md
├── images/
│   ├── popcap_logo.jpg
│   └── popcap_logo.meta.json
└── scripts/
    └── main.lua
```

更多规则见 `docs/玩家文档/respack/资源包制作指南.md`。
