local sun_token = api.register_coin({
    id = "sun_token",
    image = "IMAGE_GOLD_INGOT_1",
    image_row = 0,
    animation_ticks = 0,
    width = 50,
    height = 50,
    disappear_time = 900
})

local zombie_die_hook = "Lawn.Zombie.DieNoLoot(bool)"
local coin_collect_hook = "Lawn.Coin.Collect()"

if not api.has_hook(zombie_die_hook) then
    error("Dynamic coin example requires the Zombie.DieNoLoot hook")
end

if not api.has_hook(coin_collect_hook) then
    error("Dynamic coin example requires the Coin.Collect hook")
end

api.hook(zombie_die_hook, "prefix", function(zombie, give_achievements)
    if not give_achievements or zombie.mDead or zombie.mBoard == nil then
        return true
    end

    zombie.mBoard:AddCoin(
        math.floor(zombie.mPosX + 30),
        math.floor(zombie.mPosY + 40),
        sun_token,
        CoinMotion.Coin)
    return true
end)

api.hook(coin_collect_hook, "prefix", function(coin)
    if coin.mType == sun_token and not coin.mIsBeingCollected and coin.mBoard ~= nil then
        coin.mBoard:AddSunMoney(25)
    end

    return true
end)

api.log("Dynamic coin example loaded")
