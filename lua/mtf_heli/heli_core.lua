-- ============================================================
-- heli_core.lua — Ядро вертолёта МОГ
-- Создание сущности, высадка игроков, анимация полёта, очистка
-- ============================================================

local cfg = MTFHeli.Config

-- Ссылки на активное состояние
local activeHeli = nil
local activePlayers = {}
local pendingBots = {}

-- ============================================================
-- Утилиты
-- ============================================================

-- Плавная функция сглаживания (smootherstep)
local function Smootherstep(t)
    t = math.Clamp(t, 0, 1)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Поиск земли под точкой (TraceHull с фолбэком на TraceLine)
local function FindGround(pos)
    local mins = Vector(-13, -13, 0)
    local maxs = Vector(13, 13, 72)

    local filter = function(ent)
        return not ent:IsPlayer() and not ent:IsNPC()
    end

    local tr = util.TraceHull({
        start = pos + Vector(0, 0, 10),
        endpos = pos + Vector(0, 0, -2000),
        mins = mins,
        maxs = maxs,
        mask = MASK_PLAYERSOLID,
        filter = filter,
    })
    if tr.Hit and not tr.StartSolid then
        return tr.HitPos + Vector(0, 0, 2)
    end

    local tr2 = util.TraceLine({
        start = pos + Vector(0, 0, 10),
        endpos = pos + Vector(0, 0, -2000),
        mask = MASK_PLAYERSOLID,
        filter = filter,
    })
    if tr2.Hit then
        return tr2.HitPos + Vector(0, 0, 2)
    end

    return pos
end

-- Очистка всего состояния
function MTFHeli.Cleanup()
    hook.Remove("Think", "MTFHeliFlight")
    hook.Remove("Think", "MTFHeliBotFadeIn")
    hook.Remove("Think", "MTFHeliBotAI")
    hook.Remove("EntityEmitSound", "MTFHeliBotMute")

    MTFHeli.Sound.Cleanup()
    activePlayers = {}
    pendingBots = {}

    if IsValid(activeHeli) then
        activeHeli:Remove()
        activeHeli = nil
    end
end

-- ============================================================
-- Высадка игроков
-- ============================================================

local function DoDisembark()
    if #activePlayers == 0 then return end

    for idx, data in ipairs(activePlayers) do
        local p = data.player
        if not IsValid(p) then continue end

        -- Вызываем колбэк адаптера (Breach: SetupNormal + ApplyRoleStats + Give)
        if MTFHeli.SpawnPlayer then
            MTFHeli.SpawnPlayer(p, data.role)
        end

        local offset = cfg.DisembarkOffsets[((idx - 1) % #cfg.DisembarkOffsets) + 1]
        local groundPos = FindGround(cfg.HoverPos + offset)

        p:SetPos(groundPos)
        p:SetVelocity(Vector(0, 0, 0))
        p:SetEyeAngles(Angle(0, math.random(0, 360), 0))
    end
end

-- ============================================================
-- Создание ботов
-- ============================================================

local function CreateBots()
    if not pendingBots or not pendingBots.count or pendingBots.count <= 0 then return end

    local botCfg = pendingBots
    pendingBots = {}

    local heliPos = IsValid(activeHeli) and activeHeli:GetPos() or cfg.HoverPos
    local fadeEntities = {}
    local botNames = {}

    for i = 1, botCfg.count do
        local role = botCfg.roles[((i - 1) % #botCfg.roles) + 1]
        local bot = player.CreateNextBot("MTF Bot " .. i)
        if not IsValid(bot) then
            print("[MTF HELI] Ошибка: бот не создан. Лимит игроков?")
            continue
        end
        botNames[bot:EntIndex()] = true

        -- Инициализация бота
        bot:UnSpectate()
        bot:GodDisable()
        bot:SetNoDraw(false)
        bot:SetNoTarget(false)
        bot:SetupHands()
        bot:RemoveAllAmmo()
        bot:StripWeapons()
        bot.canblink = true
        bot:UnIgnitePlayer()

        -- Применение роли через колбэк адаптера
        if MTFHeli.SpawnPlayer then
            MTFHeli.SpawnPlayer(bot, role)
        end

        bot:SetCurrentWeaponProficiency(WEAPON_PROFICIENCY_EXPERT)

        -- Позиция
        local botOffset = cfg.DisembarkOffsets[((i - 1) % #cfg.DisembarkOffsets) + 1]
        local groundPos = FindGround(heliPos + botOffset)
        bot:SetPos(groundPos)
        bot:SetVelocity(Vector(0, 0, 0))
        bot:SetEyeAngles(Angle(0, math.random(0, 360), 0))

        -- Повторная установка позиции через тик (физика)
        local b = bot
        local gp = groundPos
        timer.Simple(cfg.BotSpawnResetDelay, function()
            if IsValid(b) then
                b:SetPos(gp)
                b:SetVelocity(Vector(0, 0, 0))
            end
        end)

        -- Плавное появление
        bot:SetRenderMode(RENDERMODE_TRANSCOLOR)
        bot:SetColor(Color(255, 255, 255, 0))
        bot:DrawShadow(false)
        table.insert(fadeEntities, { ent = bot, startTime = CurTime() + 0.5 })
    end

    -- ИИ ботов
    MTFHeli.Bot.SetupAI(botNames)

    -- Плавное появление за 1 секунду
    if #fadeEntities > 0 then
        timer.Simple(0.5, function()
            local fadeStart = CurTime()
            hook.Add("Think", "MTFHeliBotFadeIn", function()
                local allDone = true
                local elapsed = CurTime() - fadeStart
                local alpha = math.Clamp(elapsed / 1.0, 0, 1)
                for _, data in ipairs(fadeEntities) do
                    if IsValid(data.ent) then
                        data.ent:SetColor(Color(255, 255, 255, math.floor(alpha * 255)))
                        if alpha >= 1 then
                            data.ent:SetRenderMode(RENDERMODE_NORMAL)
                            data.ent:SetColor(Color(255, 255, 255, 255))
                            data.ent:DrawShadow(true)
                        else
                            allDone = false
                        end
                    end
                end
                if allDone then
                    hook.Remove("Think", "MTFHeliBotFadeIn")
                end
            end)
        end)
    end
end

-- ============================================================
-- Основная последовательность вертолёта
-- ============================================================

function MTFHeli.RunSequence(ply, players)
    MTFHeli.Cleanup()

    activePlayers = players or {}

    -- Создание сущности вертолёта
    local heli = ents.Create("mtf_heli")
    if not IsValid(heli) then
        activePlayers = {}
        if ply and IsValid(ply) then ply:ChatPrint("[MTF] Ошибка создания вертолета!") end
        return
    end

    heli:SetModel(cfg.Model)
    heli:SetPos(cfg.HoverPos)
    heli:SetAngles(Angle(0, cfg.ModelYaw, 0))
    heli:SetSolid(SOLID_NONE)
    heli:SetMoveType(MOVETYPE_NONE)
    heli:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    heli:SetRenderMode(RENDERMODE_NORMAL)
    heli:SetColor(Color(255, 255, 255, 255))
    heli:DrawShadow(true)
    heli:SetPlaybackRate(1)
    heli:ResetSequence("spawn")
    heli:Spawn()
    heli:Activate()

    activeHeli = heli
    MTFHeli.Sound.activeHeli = heli

    -- Петлевые звуки ротора
    MTFHeli.Sound.PlayLoop("heli_rotor", 1.0)
    MTFHeli.Sound.PlayLoop("heli_rotor_close", 0.7)
    MTFHeli.Sound.PlayLoop("heli_rattles", 0.5)

    -- Звуковое оповещение о прибытии (только при реальной высадке)
    timer.Simple(cfg.NotifyDelay, function()
        if not IsValid(activeHeli) then return end
        if not activePlayers or #activePlayers == 0 then return end
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then
                p:EmitSound("mtf_enter")
            end
        end
    end)

    -- Спавн игроков (канат опустился)
    timer.Simple(cfg.PlayerSpawnDelay, function()
        DoDisembark()
    end)

    -- Спавн ботов
    CreateBots()

    -- Анимация полёта
    local exitAngle = Angle(0, cfg.ModelYaw, 0)
    local exitPos = cfg.HoverPos + exitAngle:Forward() * cfg.ExitOffset.y + Vector(0, 0, cfg.ExitOffset.z)
    local holdStartTime = CurTime()
    local departStartTime = nil

    hook.Add("Think", "MTFHeliFlight", function()
        if not IsValid(activeHeli) then
            MTFHeli.Cleanup()
            return
        end

        local holdElapsed = CurTime() - holdStartTime

        MTFHeli.Sound.UpdateFilter()

        if holdElapsed < cfg.HoldTime then
            -- Фаза зависания
            activeHeli:SetFlyPhase(1)
            activeHeli:SetPhaseElapsed(holdElapsed)
            MTFHeli.Sound.CheckPhase("hover", holdElapsed)
        else
            -- Фаза вылета
            if departStartTime == nil then
                departStartTime = CurTime()
                MTFHeli.Sound.ResetPhaseTriggers()
            end

            local departElapsed = CurTime() - departStartTime
            MTFHeli.Sound.CheckPhase("depart", departElapsed)

            -- Окончание полёта
            if departElapsed >= cfg.DepartDuration then
                MTFHeli.Cleanup()
                if ply and IsValid(ply) then ply:ChatPrint("[MTF] Готово!") end
                return
            -- Звуки обрываются за DepartSoundCutoff юнитов
            elseif activeHeli:GetPos():DistToSqr(cfg.HoverPos) > cfg.DepartSoundCutoff * cfg.DepartSoundCutoff then
                MTFHeli.Sound.StopAll()
            else
                -- Плавное затухание звуков
                local fadeVol = 1.0 - (departElapsed / cfg.DepartDuration)
                MTFHeli.Sound.SetLoopVolume("heli_rotor", fadeVol)
                MTFHeli.Sound.SetLoopVolume("heli_rotor_close", fadeVol * 0.7)
                MTFHeli.Sound.SetLoopVolume("heli_rattles", fadeVol * 0.5)
            end

            -- Движение вертолёта
            local frac = Smootherstep(departElapsed / cfg.DepartDuration)
            local newPos = LerpVector(frac, cfg.HoverPos, exitPos)

            activeHeli:SetPos(newPos)
            activeHeli:SetAngles(Angle(0, cfg.ModelYaw, 0))
            activeHeli:SetFlyPhase(2)
            activeHeli:SetPhaseElapsed(departElapsed)
        end
    end)
end

-- Установка pending ботов (вызывается из breach adapter)
function MTFHeli.SetPendingBots(cfg)
    pendingBots = cfg
end

-- Очистка при выгрузке карты
hook.Add("ShutDown", "MTFHeliCleanup", function()
    MTFHeli.Cleanup()
end)
