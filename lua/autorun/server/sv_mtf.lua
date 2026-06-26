-- ============================================================
-- sv_mtf.lua — Точка входа вертолёта МОГ
-- Загружает все модули в правильном порядке.
-- Файл в autorun/server — загружается автоматически.
-- ============================================================

local base = "mtf_heli/"

-- Загрузка модулей по порядку зависимостей
include(base .. "shared.lua")
include(base .. "config.lua")
include(base .. "sound_defs.lua")
include(base .. "heli_sound.lua")
include(base .. "heli_core.lua")
include(base .. "heli_bot.lua")
include(base .. "heli_breach.lua")

