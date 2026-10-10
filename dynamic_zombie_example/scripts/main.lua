local speed_hook = "Lawn.Zombie.PickRandomSpeed()"
assert(api.has_hook(speed_hook), "Dynamic zombie example requires the updated ReMod zombie API")

-- 图鉴文本来自资源包根目录的 LawnStrings_*.txt。
local steel_bucket = api.register_zombie({
    id = "steel_bucket",
    name_key = "STEEL_BUCKET_ZOMBIE",
    reanimation = ReanimationType.Zombie,
    pick_weight = 4000,
    zombie_value = 4,
    starting_level = 1,
    first_allowed_wave = 1,
    initialize = function(zombie)
        -- 原生初始化随后应用关卡倍率，并同步各层最大血量。
        zombie.mBodyHealth = 270
        zombie.mHelmType = HelmType.Pail
        zombie.mHelmHealth = 1100
        zombie:ReanimShowPrefix("anim_bucket", 0)
        zombie:ReanimShowPrefix("anim_hair", -1)
    end,
    can_go_in_pool = true,
    almanac = true,
    almanac_image = "IMAGE_REANIM_ZOMBIE_BUCKET1"
})

api.hook(speed_hook, "postfix", function(zombie)
    if zombie.mZombieType == steel_bucket then
        zombie.mVelX = 0.35
        zombie:UpdateAnimSpeed()
    end
end)

assert(api.get_zombie_type("steel_bucket") == steel_bucket)
api.log("registered steel_bucket zombie " .. tostring(steel_bucket))
