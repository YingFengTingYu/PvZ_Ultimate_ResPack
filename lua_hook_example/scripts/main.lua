api.log("lua_hook_example loaded")

local function hook(id, phase, callback)
    if api.has_hook(id) then
        api.hook(id, phase, callback)
        api.log("hooked " .. id .. " " .. phase)
    else
        api.log("missing hook " .. id)
    end
end

hook("Lawn.Plant.Update()", "prefix", function(plant)
    plant.mPlantMaxHealth = 9999
    plant.mPlantHealth = 9999
    return true
end)

hook("Lawn.Zombie.Update()", "prefix", function(zombie)
    if zombie.mBodyHealth > 1 then
        zombie.mBodyHealth = 1
    end

    zombie.mHelmHealth = 0
    zombie.mShieldHealth = 0
    return true
end)
