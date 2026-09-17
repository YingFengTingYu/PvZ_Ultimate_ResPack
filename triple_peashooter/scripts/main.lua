local triple_peashooter = api.register_plant({
    id = "triple_peashooter",
    name_key = "TRIPLE_PEASHOOTER",
    reanimation = ReanimationType.Peashooter,
    cost = 175,
    refresh_time = 750,
    launch_rate = 150,
    subclass = PlantSubClass.Shooter,
    source = PlantSource.None,
    selectable = true,
    unlocked = true,
    chooser_order = 0,
    cache_rect = api.rect(-20, -30, 120, 130)
})

local pea_y_offsets = { -7, 0, 7 }
local fire_hook = "Lawn.Plant.Fire(Lawn.Zombie, int, Lawn.PlantWeapon)"

if not api.has_hook(fire_hook) then
    error("Triple Peashooter requires the Plant.Fire hook")
end

api.hook(fire_hook, "prefix", function(plant, target, row, weapon)
    if plant.mSeedType ~= triple_peashooter then
        return true
    end

    local offset_x, offset_y = plant:GetPeaHeadOffset(0, 0)
    local projectile_x = plant.mX + offset_x + 24
    local projectile_y = plant.mY + offset_y - 33
    if plant.mBoard:GetFlowerPotAt(plant.mPlantCol, plant.mRow) ~= nil then
        projectile_y = projectile_y - 5
    end

    local damage_range_flags = plant:GetDamageRangeFlags(weapon)
    for i = 1, #pea_y_offsets do
        local projectile = plant.mBoard:AddProjectile(
            projectile_x,
            projectile_y + pea_y_offsets[i],
            plant.mRenderOrder - 1,
            row,
            ProjectileType.Pea)
        projectile.mDamageRangeFlags = damage_range_flags
        projectile.mFromTop = plant.mOnTop
    end

    return false
end)

api.log("Triple Peashooter loaded")
