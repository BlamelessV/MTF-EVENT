-- ============================================================
-- heli_breach.lua — Адаптер для Breach
-- Единственный файл, который знает про Breach: роли, команды, хуки
-- Все остальные модули работают через колбэки MTFHeli.*
-- ============================================================

local cfg = MTFHeli.Config

-- ============================================================
-- Колбэк: спавн одного игрока/бота
-- Вызывается из heli_core при высадке и при создании ботов
-- ============================================================

MTFHeli.SpawnPlayer = function(ply, roleData)
    if not IsValid(ply) then return false end

    if ply:GTeam() ~= TEAM_SPECTATOR then return false end

    ply:UnSpectate()
    ply:GodDisable()
    ply:SetNoDraw(false)
    ply:SetNoTarget(false)
    ply:SetupHands()
    ply:RemoveAllAmmo()
    ply:StripWeapons()
    ply.canblink = true
    ply:UnIgnitePlayer()

    if roleData then
        ply:ApplyRoleStats(roleData)
    end

    if SCPCB_Inv_SetPlayerRole then
        local nclass = ply.GetNClass and ply:GetNClass() or nil
        if nclass then
            SCPCB_Inv_SetPlayerRole(ply, nclass)
        end
    end

    return true
end

-- ============================================================
-- Колбэк: команды-враги для ИИ ботов
-- ============================================================

MTFHeli.GetEnemyTeams = function()
    return { TEAM_CHAOS }
end

-- ============================================================
-- Колбэк: список ролей МОГ для ботов
-- ============================================================

MTFHeli.GetRoles = function()
    if not ALLCLASSES or not ALLCLASSES["support"] then return {} end

    local roles = {}
    for _, role in ipairs(ALLCLASSES["support"]["roles"]) do
        if role.team == TEAM_GUARD then
            table.insert(roles, role)
        end
    end
    table.sort(roles, function(a, b) return a.level < b.level end)
    return roles
end

-- ============================================================
-- Хук: Breach вызывает MTFSpawn при поддержке МОГ
-- ============================================================

hook.Add("MTFSpawn", "MTFHeli_SpawnSupport", function(players)
    if not players or #players == 0 then return end
    MTFHeli.RunSequence(nil, players)
end)

-- ============================================================
-- Хук: перехват спавна Chaos, чтобы не сажать их на площадку МОГ
-- ============================================================

hook.Add("CIChaosSpawn", "MTFHeli_ChaosRedirect", function(data)
    if not data or #data == 0 then return end
    if not SPAWN_CHAOSINS or #SPAWN_CHAOSINS == 0 then return end

    for i, d in ipairs(data) do
        if IsValid(d.player) then
            d.player:SetupNormal()
            d.player:ApplyRoleStats(d.role)
            local spawnPos = SPAWN_CHAOSINS[((i - 1) % #SPAWN_CHAOSINS) + 1]
            d.player:SetPos(spawnPos)
        end
    end

    return true
end)

-- ============================================================
-- Команда: mtf_spawn_support <число>
-- Создаёт вертолёт с ботами (только для админов)
-- ============================================================

concommand.Add("mtf_spawn_support", function(ply, cmd, args)
    if not ply:IsAdmin() then return end

    local count = math.Clamp(tonumber(args[1]) or 4, 1, cfg.MaxBots)

    local mtfRoles = MTFHeli.GetRoles()
    if #mtfRoles == 0 then
        ply:ChatPrint("[MTF] Не найдены роли MTF!")
        return
    end

    MTFHeli.SetPendingBots({ count = count, roles = mtfRoles })
    MTFHeli.RunSequence(ply, {})
end)

-- ============================================================
-- Команда: mtf_heli_test
-- Тестовый вылет вертолёта без игроков (только для админов)
-- ============================================================

concommand.Add("mtf_heli_test", function(ply)
    if not ply:IsAdmin() then return end
    MTFHeli.RunSequence(ply, {})
end)

print("[MTF HELI] Breach-адаптер загружен.")
