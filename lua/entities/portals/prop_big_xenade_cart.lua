
AddCSLuaFile()

ENT.Base 			= "base_gmodentity"
ENT.Type 			= "anim"
ENT.PrintName 		= "Xen Grenade Cart"
ENT.Author 			= "L1makenor1"
ENT.Purpose 		= "Fight for your life!"
ENT.Instructions 	= "Spawn it and survive the waves of xenians!"
ENT.Category		= "Entropy : Zero 2"
ENT.Spawnable = true
ENT.AdminOnly = false


-- Sounds

sound.Add({
    name = "ez2_cart_hop",
	channel = CHAN_STATIC,
	volume = 0.9,
	level = 80,
	pitch = 100,
	sound = {
    "zezt/cascade/cart_blip_hop.wav",
    },
})

sound.Add({
    name = "ez2_cart_cacophony",
	channel = CHAN_STATIC,
	volume = 0.9,
	level = 80,
	pitch = 100,
	sound = {
    "zezt/cascade/cart_blip_cacophony_loop.wav",
    },
})

local XenGrenade_Schlorp = Sound( 'XenGrenade_Schlorp' )

---

---------------------------------------------------------------------------------------------------------------------------------------------
if (CLIENT) then
	function ENT:Draw()
		self:DrawModel()
	end
end
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function ENT:Initialize()
	self:SetModel("models/props_wasteland/laundry_cart002.mdl")
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:SetNoDraw(true)
	self:DrawShadow(false)

	timer.Simple(GetConVarNumber("lima_ez2_bab_cart_explode_time"),function() if IsValid(self) then self:Explode() end end)
	if SERVER then
self.Cacophony = CreateSound(self,"ez2_cart_cacophony")
self.Cacophony:Play()
local xencart = ents.Create("prop_dynamic")
	xencart:SetPos(self:GetPos())
	xencart:SetAngles(self:GetAngles())
	xencart:SetParent(self)
	xencart:SetModel("models/big_xenade_cart.mdl")
	xencart:Spawn()
	xencart:Fire("SetDefaultAnimation","ready_postidle",0.01)
	xencart:Fire("SetAnimation","ready_postidle",0)
	self:SetNW2Entity("xencart",xencart)
	--xencart:Fire("SetAnimation","ready",0)
	local fusessprites = ents.Create("env_sprite")
	fusessprites:SetPos(xencart:GetAttachment(xencart:LookupAttachment("cart_fuses")).Pos)	
	fusessprites:SetAngles(self:GetAngles())
	fusessprites:SetKeyValue("model", "sprites/redglow2.vmt")
	fusessprites:SetKeyValue("HDRColorScale", 1.0)
	fusessprites:SetKeyValue("GlowProxySize", 12)
	fusessprites:SetKeyValue("framerate", 10)
	fusessprites:SetKeyValue("renderfx", 13)
	fusessprites:SetKeyValue("rendermode", 3)
	fusessprites:SetKeyValue("scale", 2)
	fusessprites:SetKeyValue("rendercolor", "0 255 255")
	fusessprites:SetParent(xencart,xencart:LookupAttachment("cart_fuses"))
	fusessprites:Spawn()
	self.FuseSprites = {}
	table.insert(self.FuseSprites,fusessprites)
	for i=1, 10 do
	local fuse = "fuse0"..i
	if i > 9 then
	fuse = "fuse"..i
	end
	local fusessprites = ents.Create("env_sprite")
	fusessprites:SetPos(xencart:GetAttachment(xencart:LookupAttachment(fuse)).Pos)	
	fusessprites:SetAngles(self:GetAngles())
	fusessprites:SetKeyValue("model", "sprites/redglow2.vmt")
	fusessprites:SetKeyValue("HDRColorScale", 1.0)
	fusessprites:SetKeyValue("GlowProxySize", 12)
	fusessprites:SetKeyValue("framerate", 10)
	fusessprites:SetKeyValue("renderfx", 13)
	fusessprites:SetKeyValue("rendermode", 9)
	fusessprites:SetKeyValue("scale", 0.5)
	fusessprites:SetKeyValue("rendercolor", "0 255 255")
	fusessprites:SetParent(xencart,xencart:LookupAttachment(fuse))
	fusessprites:Spawn()
	table.insert(self.FuseSprites,fusessprites)
	end
	
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:Wake() end
    end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:PhysicsCollide(data, physobj)
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:Think()
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:Explode()
self:EmitSound("ez2_cart_hop")
timer.Simple(1,function() if IsValid(self) then
local xencart = self:GetNW2Entity("xencart")
for i=1, 10 do
	local fuse = "fuse0"..i
	if i > 9 then
	fuse = "fuse"..i
	end
ParticleEffect( 'xen_striderbuster_attach', ( xencart:GetAttachment(xencart:LookupAttachment(fuse)).Pos ), Angle( 0, 0, 0 ) )
end
end end)
if SERVER then
local phys = self:GetPhysicsObject()
if IsValid(phys) then
phys:SetVelocity(Vector(0,0,GetConVarNumber("lima_ez2_bab_cart_strenght")))
phys:AddAngleVelocity(Vector(math.random(-80,80),math.random(-80,80),math.random(-80,80)))
end
timer.Simple(1,function() if IsValid(self) then
local cascade = ents.Create("prop_big_and_bad")
cascade:SetOwner(self)
cascade:SetPos(self:GetPos())
cascade:Spawn()
undo.ReplaceEntity( self, cascade )
cleanup.ReplaceEntity( self, cascade )
self:Remove()
end end)
for i=1, #self.FuseSprites do
local fuse = self.FuseSprites[i]
if IsValid(fuse) then
fuse:SetKeyValue("renderfx", 1)
fuse:SetKeyValue("rendercolor", "0 255 0")
end
end 
self.Cacophony:Stop()
end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:OnRemove()
if SERVER then
self.Cacophony:Stop()
end
end
