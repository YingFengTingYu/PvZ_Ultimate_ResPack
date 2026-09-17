api.log("red_shader_example loaded")

local effect = nil
local unavailable_logged = false
local active_effect = nil
local active_run_handle = nil
local active_pass = nil

local function load_resources()
    if effect == nil then
        effect = Resources.GetRenderEffectByName("EFFECT_RED")
    end

    return effect ~= nil
end

local function log_unavailable(message)
    if not unavailable_logged then
        api.log(message)
        unavailable_logged = true
    end
end

api.hook("Lawn.Board.DrawGameObjects(Sexy.Graphics)", "prefix", function(board, graphics)
    if active_run_handle ~= nil then
        return
    end

    if not RenderEffects.IsSupported() or not load_resources() then
        log_unavailable("red_shader_example skipped: RenderEffect is unavailable")
        return
    end

    effect:SetCurrentTechnique("Default", true)
    if effect:GetCurrentTechniqueName() == "" then
        log_unavailable("red_shader_example skipped: no compatible technique")
        return
    end

    local pass_count, run_handle = effect:Begin(graphics.mRenderContext)
    if pass_count ~= 1 then
        effect:End(run_handle)
        log_unavailable("red_shader_example skipped: the example requires a single-pass technique")
        return
    end

    active_effect = effect
    active_run_handle = run_handle
    active_pass = 0
    effect:BeginPass(run_handle, active_pass)
end)

api.hook("Lawn.Board.DrawGameObjects(Sexy.Graphics)", "postfix", function(board, graphics)
    if active_run_handle == nil then
        return
    end

    local current_effect = active_effect
    local run_handle = active_run_handle
    local pass = active_pass
    active_effect = nil
    active_run_handle = nil
    active_pass = nil

    current_effect:EndPass(run_handle, pass)
    current_effect:End(run_handle)
end)
