local heavy_pea = api.register_projectile({
    id = "heavy_pea",
    image = "IMAGE_PROJECTILESNOWPEA",
    damage = 40,
    image_row = 0,
    animation_ticks = 0,
    width = 40,
    height = 40
})

local fire_hook = "Lawn.Plant.Fire(Lawn.Zombie, int, Lawn.PlantWeapon)"

if not api.has_hook(fire_hook) then
    error("Dynamic projectile example requires the Plant.Fire hook")
end

api.hook(fire_hook, "prefix", function(plant, target, row, weapon)
    if plant.mSeedType ~= SeedType.Peashooter then
        return true
    end

    local offset_x, offset_y = plant:GetPeaHeadOffset(0, 0)
    local projectile_x = plant.mX + offset_x + 24
    local projectile_y = plant.mY + offset_y - 33
    if plant.mBoard:GetFlowerPotAt(plant.mPlantCol, plant.mRow) ~= nil then
        projectile_y = projectile_y - 5
    end

    local projectile = plant.mBoard:AddProjectile(
        projectile_x,
        projectile_y,
        plant.mRenderOrder - 1,
        row,
        heavy_pea)
    projectile.mDamageRangeFlags = plant:GetDamageRangeFlags(weapon)
    projectile.mFromTop = plant.mOnTop
    return false
end)

api.log("Dynamic projectile example loaded")
