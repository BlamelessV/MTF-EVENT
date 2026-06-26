-- ============================================================
-- heli_bot.lua — ИИ ботов МОГ
-- Поиск врагов, движение, стрельба, отключение звука шагов
-- ============================================================

MTFHeli.Bot = {}

local cfg = MTFHeli.Config
local activeBotNames = {}

-- Установить ИИ для набора ботов
function MTFHeli.Bot.SetupAI(botNames)
    activeBotNames = botNames

    -- Хук ИИ: каждый тик проверяем врагов и стреляем
    hook.Add("Think", "MTFHeliBotAI", function()
        for botIdx in pairs(activeBotNames) do
            local bot = Entity(botIdx)
            if not IsValid(bot) or not bot:IsPlayer() or not bot:Alive() then
                activeBotNames[botIdx] = nil
                continue
            end

            local botPos = bot:GetPos()
            local nearestEnemy = nil
            local nearestDist = cfg.BotEnemyRange

            -- Ищем ближайшего врага из команд-врагов
            local enemyTeams = MTFHeli.GetEnemyTeams and MTFHeli.GetEnemyTeams() or {}
            for _, p in pairs(player.GetAll()) do
                if IsValid(p) and p ~= bot and p:Alive() then
                    local pTeam = p:GTeam()
                    local isEnemy = false
                    for _, t in ipairs(enemyTeams) do
                        if pTeam == t then isEnemy = true break end
                    end
                    if isEnemy then
                        local dist = botPos:Distance(p:GetPos())
                        if dist < nearestDist then
                            nearestDist = dist
                            nearestEnemy = p
                        end
                    end
                end
            end

            -- Поворачиваемся к врагу
            if IsValid(nearestEnemy) then
                local dir = (nearestEnemy:GetPos() - botPos):GetNormalized()
                local ang = dir:Angle()
                bot:SetEyeAngles(Angle(ang.p, ang.y, 0))

                -- Стрельба (если оружие не melee/physgun)
                local wep = bot:GetActiveWeapon()
                if IsValid(wep) then
                    local wepClass = wep:GetClass()
                    if wepClass ~= "weapon_crowbar" and wepClass ~= "weapon_physgun" then
                        wep:SetNextPrimaryFire(CurTime() + cfg.BotFireInterval)
                        wep:SetNextSecondaryFire(CurTime() + cfg.BotFireInterval)
                    end
                end

                -- Движение к врагу
                if nearestDist > 150 then
                    local moveDir = (nearestEnemy:GetPos() - botPos):GetNormalized() * cfg.BotMoveSpeed
                    bot:SetVelocity(Vector(moveDir.x, moveDir.y, 0))
                end
            end
        end
    end)

    -- Отключение звука шагов ботов (только footsteps)
    hook.Add("EntityEmitSound", "MTFHeliBotMute", function(data)
        local ent = data.Entity
        if IsValid(ent) and ent:IsPlayer() and activeBotNames[ent:EntIndex()] then
            return false
        end
    end)
end

-- Очистка ИИ
function MTFHeli.Bot.Cleanup()
    hook.Remove("Think", "MTFHeliBotAI")
    hook.Remove("EntityEmitSound", "MTFHeliBotMute")
    activeBotNames = {}
end
