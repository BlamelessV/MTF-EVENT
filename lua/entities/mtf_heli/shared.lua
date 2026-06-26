ENT.Base = "base_gmodentity"
ENT.Type = "anim"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.PrintName = "MTF Helicopter"
ENT.Category = "MTF Spawn"
ENT.Model = Model("models/hh/veh/heli.mdl")
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "FlyPhase")
    self:NetworkVar("Float", 0, "PhaseElapsed")
end

function ENT:Initialize()
    if SERVER then
        self:SetModel(self.Model)
        self:SetSolid(SOLID_NONE)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetRenderMode(RENDERMODE_NORMAL)
        self:SetPlaybackRate(1)
        self:ResetSequence("spawn")
        self:SetFlyPhase(0)
        self:SetPhaseElapsed(0)
    end
end

function ENT:Think()
    self:NextThink(CurTime())
    return true
end

function ENT:Draw()
    self:DrawModel()
end
