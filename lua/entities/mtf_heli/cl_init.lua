include("shared.lua")

function ENT:Think()
    self:NextThink(CurTime())
    return true
end

function ENT:Draw()
    self:DrawModel()
end
