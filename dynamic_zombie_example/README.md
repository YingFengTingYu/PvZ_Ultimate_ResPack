# 动态僵尸 Lua 模组

注册一个独立类型的钢桶僵尸，使用原版僵尸动画和铁桶图片，无需额外美术资源：本体 270 血、铁桶 1100 血、移动速度 0.35、出怪权重 4000、波次点数消耗 4。血量仍受原生关卡倍率影响。

需要游戏支持 `api.register_zombie` 的 `initialize(zombie)` 回调和 `Lawn.Zombie.PickRandomSpeed()` hook，对应游戏仓库更新后的 `Feature/ReMod` 分支。旧版仅支持 `body_health`、`speed` 等注册参数的实现不能运行本示例。

## 使用方法

1. 将本目录中的 `pack.json`、`scripts` 和四个 `LawnStrings_*.txt` 文件一起打包成 ZIP，确保 `pack.json` 在 ZIP 根目录。
2. 在游戏资源包界面导入并启用资源包，开启“启用 Lua 脚本”。
3. 重启游戏，在僵尸图鉴的模组页查看钢桶僵尸；小窗口使用静态铁桶图片，详情页使用完整预览僵尸。
4. 进入单机冒险或无尽等使用原生随机出怪器的关卡，钢桶僵尸会参与随机出怪。权重不保证每波出现；波次剩余点数不足 4 时不会选中它。

## 脚本说明

- `initialize(zombie)` 在基础动画就绪后设置本体血量、防具类型和防具血量，同时显示铁桶轨道、隐藏头发；引擎随后同步最大血量。
- `PickRandomSpeed` postfix 在原生选速之后设置 `mVelX`，并调用 `UpdateAnimSpeed` 同步行走动画。筛选条件只匹配本模组类型，不改变其他僵尸。
- `initialize` 也会用于图鉴预览，因此不依赖战场或刷新波次。
- 该类型没有 `base_type`，使用普通步行 AI，不会继承巨人、舞王等特殊行为。
- 图鉴名称使用 `[STEEL_BUCKET_ZOMBIE]`，介绍使用 `[STEEL_BUCKET_ZOMBIE_DESCRIPTION]`；四种语言文件都提供这些键。
- 动态类型整数只在本次运行有效。存档使用资源包 ID 与局部 ID 组合，读取该存档时必须启用同一资源包。
- 不支持联机、对战或合作模式；创意关卡另需把注册类型加入运行时允许列表。

完整 API 说明见[游戏 Lua 脚本模组指南](https://github.com/YingFengTingYu/PvZ_Ultimate/blob/Feature/ReMod/docs/玩家文档/Lua脚本模组指南.md#注册僵尸)。
