-- ============================================================
-- sound_defs.lua — Определения звуков вертолёта
-- Все sound.Add ТОЛЬКО здесь. Никаких дублей.
--
-- level = уровень звукового давления (dB). Определяет радиус слышимости:
--   80  = ~1000 юнитов  (ближние звуки: сиденья, двери)
--   85  = ~1500 юнитов  (средние: канат)
--   90  = ~2000 юнитов  (дальние: дребезг, дверь)
--   100 = ~4000 юнитов  (максимальные: ротор, оповещение)
-- ============================================================

-- Звуки вертолёта
sound.Add({ name = "heli_rotor",       channel = CHAN_AUTO,   volume = 1.0, level = 100, sound = "base_move2.wav" })
sound.Add({ name = "heli_rotor_close", channel = CHAN_AUTO,   volume = 1.0, level = 100, sound = "base_moveclose.wav" })
sound.Add({ name = "heli_rattles",     channel = CHAN_AUTO,   volume = 1.0, level = 90,  sound = "sas1_veh1_ceilingrattles_spot_stat.wav" })
sound.Add({ name = "heli_door",        channel = CHAN_STATIC, volume = 1.0, level = 90,  sound = "sas1_veh1_door_ster_pan.wav" })
sound.Add({ name = "heli_rope",        channel = CHAN_AUTO,   volume = 1.0, level = 85,  sound = "sas1_veh1_rope_spot_stat.wav" })
sound.Add({ name = "heli_seat1_npc",   channel = CHAN_AUTO,   volume = 1.0, level = 80,  sound = "sas1_veh1_foley_seat1_npc.wav" })
sound.Add({ name = "heli_seat2_npc",   channel = CHAN_AUTO,   volume = 1.0, level = 80,  sound = "sas1_veh1_foley_seat2_npc.wav" })
sound.Add({ name = "heli_seat3_npc",   channel = CHAN_AUTO,   volume = 1.0, level = 80,  sound = "sas1_veh1_foley_seat3_npc.wav" })
sound.Add({ name = "heli_doorman_npc", channel = CHAN_AUTO,   volume = 1.0, level = 80,  sound = "sas1_veh1_foley_doorman_npc.wav" })

-- Оповещение о прибытии МОГ (глобальное, слышно всем)
sound.Add({ name = "mtf_enter", channel = CHAN_STATIC, volume = 1.0, level = 100, sound = "mtf_enter.wav" })
