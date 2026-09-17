# RenderEffect 视觉实验室

这是一个只使用资源包 Lua、LuaUI 和编译后 PopFX 的视觉玩法包，不修改任何游戏代码。它在 `Board.DrawGameObjects(Graphics)` 原绘制前开启单 pass RenderEffect，并在原绘制后关闭，所以植物、僵尸、弹丸、掉落物和棋盘上的其他普通绘制会直接经过 shader；勾选“连草坪背景一起处理”后，`Board.DrawBackdrop(Graphics)` 也会进入相同流程。

## 内置效果

- **糖果风暴**：按屏幕位置和时间旋转色相，提高饱和度并产生柔和呼吸。
- **街机显像管**：色阶压缩、扫描线、荧光栅格和轻微暗角。
- **月光幽灵**：把亮度映射为冷蓝月光，并让高光缓慢流动。
- **热成像**：按亮度映射紫、红、黄、白四色温度带。
- **X 光反相**：反相、高对比和青蓝色荧光。
- **故障派对**：按屏幕横带随机交换 RGB 通道，加入数字噪声和亮线。
- **漫画网点**：高饱和色阶、屏幕空间印刷网点和粗粝墨色。
- **尸潮警报**：红色脉冲和纵向扫光；也可以在每次生成僵尸波时暂时覆盖当前效果。

屏幕左侧的“特效 / FX”悬浮按钮会打开控制台。可以切换效果、关闭 shader、自动轮播、选择是否处理背景、开关尸潮响应，并调节强度与动画速度。控制台由棋盘绘制之后的 LuaUI 显示，不会被当前 shader 染色。

## 使用方法

1. 将整个 `render_effect_lab` 文件夹压缩为 ZIP。
2. 在游戏资源包界面导入并启用。
3. 开启“启用 Lua 脚本”并确认安全提示。
4. 重启游戏并进入任意关卡，点击屏幕左侧的“特效 / FX”按钮。

当前后端不支持 RenderEffect、编译资源缺少当前平台变体或 technique 无效时，脚本会保留原始绘制，并在控制台状态和游戏日志中说明原因。

## 目录结构

```text
render_effect_lab/
├── pack.json
├── README.md
├── effects/
│   └── mood_machine.popfx       -> EFFECT_MOOD_MACHINE
├── scripts/
│   └── main.lua
└── source/
    ├── MoodMachine.popfx.json
    └── MoodMachine.slang
```

游戏只加载 `effects/mood_machine.popfx`；`source/` 用于学习和重新编译。重新编译命令：

```powershell
.\PopFxCompiler.exe `
  --input .\source\MoodMachine.popfx.json `
  --output .\effects\mood_machine.popfx
```

## 设计与兼容性说明

RenderEffect 在这里作用于原有的逐图元绘制，并不是对整张最终帧缓冲做后处理。因此这些效果只采样当前图元的 `SourceTexture`，不会尝试跨图元模糊或读取相邻图集区域；扫描线、故障横带和网点使用顶点传入的裁剪空间坐标，使图案在整个屏幕上连续。所有 technique 都只有一个 pass，可以安全地跨越原绘制方法的前置和后置 hook。

动画时间、强度、警报包络和保留值在 PopFX 中有意声明为四个独立 `Float`，不要合并成 `Vector4`。D3D9 的兼容常量布局会把前四个标量分别写入 `c0.x`、`c1.x`、`c2.x` 和 `c3.x`；合并后 DX9 读取不到 `Vector4` 的 `y`、`z` 分量，强度会退化为零。

`.popfx` 包含 D3D9、D3D11、D3D12、Vulkan、OpenGL、OpenGL ES、WebGL、Metal 和 WebGPU 变体。多个资源包如果同时在同一个绘制 hook 中管理 RenderEffect，作用域可能互相嵌套；遇到画面异常时应只保留一个此类全局视觉包。