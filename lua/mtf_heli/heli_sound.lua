-- ============================================================
-- heli_sound.lua — Звуковая система вертолёта
-- RecipientFilter ВКЛЮЧАЕТ ВСЕХ игроков (включая спектаторов).
-- Фильтр обновляется каждый тик + перед CreateSound.
-- ============================================================

MTFHeli.Sound = {}

local cfg = MTFHeli.Config
local heliFilter = RecipientFilter()

-- Ссылки на активные сущности
MTFHeli.Sound.activeHeli = nil

-- Прокси-сущности
local loopProxies = {}
local loopVolumes = {}
local allProxies = {}
local phaseTriggered = {}

-- Ссылка на activePlayers из heli_core (устанавливается при запуске секвенции)
MTFHeli.Sound.GetActivePlayers = nil

-- Фильтр:
-- 1) Игроки из activePlayers (спектаторы, ждущие высадки) — всегда
-- 2) Живые игроки снаружи (Z >= HoverPos.z - OutsideZ) — слышат роторы
-- 3) Живые игроки внутри комплекса — НЕ слышат
function MTFHeli.Sound.UpdateFilter()
    heliFilter:RemoveAllPlayers()

    local minZ = cfg.HoverPos.z - cfg.OutsideZ

    -- Множество игроков, ожидающих высадку
    local pendingSet = {}
    if MTFHeli.Sound.GetActivePlayers then
        for _, data in ipairs(MTFHeli.Sound.GetActivePlayers()) do
            if IsValid(data.player) then
                pendingSet[data.player] = true
            end
        end
    end

    for _, p in ipairs(player.GetAll()) do
        if not IsValid(p) then continue end

        -- Спектаторы, которых скоро заспавнят — всегда в фильтре
        if pendingSet[p] then
            heliFilter:AddPlayer(p)
            continue
        end

        -- Живые игроки снаружи — слышат роторы
        if p:Alive() and p:GetPos().z >= minZ then
            heliFilter:AddPlayer(p)
        end
    end
end

function MTFHeli.Sound.StopAll()
    for _, proxy in ipairs(allProxies) do
        if IsValid(proxy) and proxy._cs then
            proxy._cs:Stop()
        end
    end
    allProxies = {}
    loopProxies = {}
    loopVolumes = {}

    local heli = MTFHeli.Sound.activeHeli
    if IsValid(heli) then
        for _, name in ipairs({"heli_rotor","heli_rotor_close","heli_rattles","heli_door","heli_rope","heli_seat1_npc","heli_seat2_npc","heli_seat3_npc","heli_doorman_npc"}) do
            heli:StopSound(name)
        end
    end
end

local function CreateProxySound(parent, soundName, initialVolume)
    if not IsValid(parent) then return nil end
    initialVolume = initialVolume or 1.0

    MTFHeli.Sound.UpdateFilter()

    local proxy = ents.Create("base_anim")
    if not IsValid(proxy) then return nil end

    proxy:SetNoDraw(true)
    proxy:SetPos(parent:GetPos())
    proxy:SetParent(parent)
    proxy:Spawn()
    proxy:Activate()

    local cs = CreateSound(proxy, soundName, heliFilter)
    if not cs then
        proxy:Remove()
        return nil
    end

    cs:ChangeVolume(0, 0)
    cs:Play()
    cs:ChangeVolume(initialVolume, 0.5)

    proxy._cs = cs
    proxy._sndName = soundName

    parent:DeleteOnRemove(proxy)
    table.insert(allProxies, proxy)
    return proxy
end

function MTFHeli.Sound.PlayLoop(soundName, initialVolume)
    local proxy = CreateProxySound(MTFHeli.Sound.activeHeli, soundName, initialVolume)
    if proxy then
        loopProxies[soundName] = proxy
        loopVolumes[soundName] = initialVolume
    end
    return proxy
end

function MTFHeli.Sound.SetLoopVolume(soundName, vol)
    local proxy = loopProxies[soundName]
    if IsValid(proxy) and proxy._cs then
        proxy._cs:ChangeVolume(math.Clamp(vol, 0, 1), 0.1)
        loopVolumes[soundName] = vol
    end
end

function MTFHeli.Sound.PlayOneShot(soundName)
    local heli = MTFHeli.Sound.activeHeli
    if IsValid(heli) then
        heli:EmitSound(soundName)
    end
end

-- Оповещение: SendLua — гарантированно всем клиентам
function MTFHeli.Sound.PlayNotification()
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            p:SendLua('surface.PlaySound("mtf_enter.wav")')
        end
    end
end

local AnimationSounds = {
    hover = {
        { t = 0.0, snd = "heli_door",   vol = 1.0 },
        { t = 2.5, snd = "heli_rope",   vol = 1.0 },
    },
    depart = {
        { t = 0.0, snd = "heli_seat1_npc", vol = 0.8 },
        { t = 0.3, snd = "heli_seat2_npc", vol = 0.8 },
        { t = 0.6, snd = "heli_seat3_npc", vol = 0.8 },
        { t = 1.0, snd = "heli_doorman_npc", vol = 0.7 },
    },
}

function MTFHeli.Sound.CheckPhase(phaseName, elapsed)
    local sounds = AnimationSounds[phaseName]
    if not sounds then return end

    for _, sndData in ipairs(sounds) do
        local key = phaseName .. "_" .. sndData.snd
        if elapsed >= sndData.t and not phaseTriggered[key] then
            phaseTriggered[key] = true
            MTFHeli.Sound.PlayOneShot(sndData.snd)
        end
    end
end

function MTFHeli.Sound.ResetPhaseTriggers()
    phaseTriggered = {}
end

function MTFHeli.Sound.Cleanup()
    MTFHeli.Sound.StopAll()
    loopProxies = {}
    loopVolumes = {}
    allProxies = {}
    phaseTriggered = {}
end

-- Перезапуск loop-звуков: нужно после высадки игроков,
-- т.к. CreateSound с RecipientFilter кэширует список при Play().
-- Новые игроки (стали Alive после спавна) не слышат старые звуки.
function MTFHeli.Sound.RestartLoops()
    local savedVolumes = {}
    for name, _ in pairs(loopProxies) do
        savedVolumes[name] = loopVolumes[name] or 1.0
    end

    MTFHeli.Sound.StopAll()

    for name, vol in pairs(savedVolumes) do
        MTFHeli.Sound.PlayLoop(name, vol)
    end
end
