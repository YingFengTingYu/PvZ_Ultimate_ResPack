# 动态子弹 Lua 模组

这是一个可直接导入的目录式资源包示例。它注册一颗独立的动态子弹，并将普通豌豆射手发出的豌豆替换为该子弹：

- 使用寒冰豌豆图片，但不继承寒冰豌豆的减速逻辑；
- 基础伤害为 40；
- 使用原生直线运动、碰撞、伤害和死亡流程；
- 不包含子弹专用的 C# 行为。

动态子弹没有 `base_type`。图片只决定外观，特殊效果应通过 `Projectile.ProjectileInitialize`、`Projectile.Update`、`Projectile.DoImpact` 等 hook 实现。首版不支持联机同步。

使用方法：

1. 将整个 `dynamic_projectile_example` 文件夹压缩为 ZIP。
2. 在游戏的资源包界面导入并启用该资源包。
3. 在“设置 - 资源包”中开启“启用 Lua 脚本”。
4. 重启游戏并种植普通豌豆射手。
