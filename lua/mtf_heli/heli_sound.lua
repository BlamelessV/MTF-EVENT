-- ============================================================
-- heli_sound.lua — Звуковая система вертолёта
-- Управление RecipientFilter, CreateSound прокси, fade, триггеры
-- ============================================================

MTFHeli.Sound = {}

local cfg = MTFHeli.Config
local heliFilter = RecipientFilter()

-- Ссылки на активные сущности (устанавливаются из heli_core)
MTFHeli.Sound.activeHeli = nil

-- Прокси-сущности для loop-звуков и одноразовых звуков
local loopProxies = {}
local allProxies = {}
local phaseTriggered = {}

-- Обновление фильтра: добавляем игроков вне комплекса (Z >= HOVER_POS.z - OutsideZ)
function MTFHeli.Sound.UpdateFilter()
    heliFilter:RemoveAllPlayers()
    local heli = MTFHeli.Sound.activeHeli
    if not IsValid(heli) then return end

    local minZ = cfg.HoverPos.z - cfg.OutsideZ
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:Alive() and p:GetPos().z >= minZ then
            heliFilter:AddPlayer(p)
        end
    end
end

-- Остановить все звуки (прокси + стоп на хели)
function MTFHeli.Sound.StopAll()
    for _, proxy in ipairs(allProxies) do
        if IsValid(proxy) then
            proxy:StopSound(proxy._sndName)
            if proxy._cs then proxy._cs:Stop() end
        end
    end
    allProxies = {}
    loopProxies = {}

    local heli = MTFHeli.Sound.activeHeli
    if IsValid(heli) then
        for _, name in ipairs({"heli_rotor","heli_rotor_close","heli_rattles","heli_door","heli_rope","heli_seat1_npc","heli_seat2_npc","heli_seat3_npc","heli_doorman_npc"}) do
            heli:StopSound(name)
        end
    end
end

-- Создать звук на прокси-сущности, привязанной к родителю
local function CreateProxySound(parent, soundName, initialVolume)
    if not IsValid(parent) then return nil end
    initialVolume = initialVolume or 1.0

    local proxy = ents.Create("base_anim")
    if not IsValid(proxy) then return nil end

    proxy:SetNoDraw(true)
    proxy:SetPos(parent:GetPos())
    proxy:SetParent(parent)
    proxy:Spawn()
    proxy:Activate()

    MTFHeli.Sound.UpdateFilter()

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

-- Петлевой звук (rotor, rattles)
function MTFHeli.Sound.PlayLoop(soundName, initialVolume)
    local proxy = CreateProxySound(MTFHeli.Sound.activeHeli, soundName, initialVolume)
    if proxy then
        loopProxies[soundName] = proxy
    end
    return proxy
end

-- Изменить громкость петлевого звука (плавно за 0.1 сек)
function MTFHeli.Sound.SetLoopVolume(soundName, vol)
    local proxy = loopProxies[soundName]
    if IsValid(proxy) and proxy._cs then
        proxy._cs:ChangeVolume(math.Clamp(vol, 0, 1), 0.1)
    end
end

-- Одноразовый звук (дверь, канат, сиденья)
function MTFHeli.Sound.PlayOneShot(soundName)
    local heli = MTFHeli.Sound.activeHeli
    if IsValid(heli) then
        heli:EmitSound(soundName)
    end
end

-- Триггеры звуков по фазам анимации
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

-- Проверить и воспроизвести звуки для текущей фазы
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

-- Сброс триггеров (при смене фазы)
function MTFHeli.Sound.ResetPhaseTriggers()
    phaseTriggered = {}
end

-- Очистка всех звуков и прокси
function MTFHeli.Sound.Cleanup()
    MTFHeli.Sound.StopAll()
    loopProxies = {}
    allProxies = {}
    phaseTriggered = {}
end
