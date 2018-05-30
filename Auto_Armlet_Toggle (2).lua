local Utility = require("scripts/Utility")
local Armlet = {}
config:SetParameter("Hotkey", "L", config.TYPE_HOTKEY)
config:SetParameter("MinimumHP", 200)
config:SetParameter("ToggleAlways", false)
config:Load()

hotkey = config.Hotkey
minhp = config.MinimumHP

local xx,yy = 10,client.screenSize.y/25.714
local reg = nil local active = false
local F14 = drawMgr:CreateFont("f14","Tahoma",14,550)
local statusText = drawMgr:CreateText(xx,yy,-1,"Auto armlet toggle: Off",F14)
local incoming_projectiles = {} local incoming_damage = 0 local toggle = false
local testedIncomingDamage = 0

local ARMLET_DELAY = 1000
local ARMLET_GAIN_TIME = 800

function Key(msg,code)
    if msg ~= KEY_UP or code ~= hotkey or client.chat then return end
	if not active then
		active = true
		statusText.text = "Auto armlet toggle: On"
		return true
	else
		active = false
		statusText.text = "Auto armlet toggle: Off"
		return true
	end

end

function Tick( tick )
	if not PlayingGame() or client.console or client.paused then return end
	
	local me = entityList:GetMyHero()
	local player = entityList:GetMyPlayer()
	
	if not reg then
		script:RegisterEvent(EVENT_KEY,Key)
		reg = true
		incoming_projectiles = {} 
		incoming_damage = 0
	end
	
	local armlet = me:FindItem("item_armlet")
	
	if not armlet or not active then incoming_damage = 0 incoming_projectiles = {} toggle = false return end
	
	local armState = me:DoesHaveModifier("modifier_item_armlet_unholy_strength")
	local enemies = entityList:GetEntities({type=LuaEntity.TYPE_HERO,alive=true,visible=true,team=me:GetEnemyTeam()})
	if not me.alive then
		incoming_damage = 0
		incoming_projectiles = {}
		toggle = false
		return
	end
	
	Animations.entities = {}
	local anientiCount = 1
	Animations.entities[1] = me
	
	for i = 1,#enemies do
		anientiCount = anientiCount + 1
		Animations.entities[anientiCount] = enemies[i]
	end
	
	if me:DoesHaveModifier("modifier_ice_blast") then
		if not me:IsStunned() and armState and SleepCheck() and not me:IsInvisible() then
			me:CastItem("item_armlet")
			Sleep(ARMLET_DELAY)
		end
		return
	end

	if not me:IsStunned() and player.orderId == Player.ORDER_ATTACKENTITY and player.target and not me:IsInvisible() and player.target.hero and not armState and SleepCheck() and (GetDistance2D(player.target,me) < me.attackRange+25 or Animations.isAttacking(me)) then
		me:CastItem("item_armlet")
		Sleep(ARMLET_DELAY)
	end
	
	local closeEnemies = 
			entityList:GetEntities
				(
					function (v) 
						return 
							(
								(v.hero or v.creep) 
								and v.alive 
								and v.team ~= me.team 
								and GetDistance2D(me,v) < v.attackRange+100 
								and (not v:IsRanged() or GetDistance2D(me,v) < 500)	
								and not Animations.CanMove(v) 
								and Animations.isAttacking(v)
								and (math.max(math.abs(FindAngleR(v) 
									- math.rad(FindAngleBetween(v, me))) 
									- 0.20, 0)) == 0
								and (Animations.GetAttackTime(v)*1000 
									- Animations.getAttackDuration(v)
									- client.latency - ((1 / Animations.maxCount) 
									* 3 * (1 + (1 - 1/ Animations.maxCount)))
									*1000) < ARMLET_GAIN_TIME/1.5
							) 
					end
				)
											
	local closeProjectiles = 
			entityList:GetProjectiles
				(
					function (v) 
						return 
							(
								v.target 
								and v.target == me 
								and (GetDistance2D(v,me)/v.speed)*1000 < ARMLET_GAIN_TIME/2.5
							) 
					end
				)
	
	if armState and SleepCheck("item_armlet") and me:CanCast() then
		if me.health < 250 and #closeEnemies < 1 and #closeProjectiles < 1 then
			me:CastItem("item_armlet")
			me:CastItem("item_armlet")
			Sleep(1000,"item_armlet")
			toggled = true
			return
		end
	end
end

function Load()
	if PlayingGame() then
		local me = entityList:GetMyHero()
		if not me then 
			script:Disable()
		else
			incoming_projectiles = {} 
			incoming_damage = 0
			testedIncomingDamage = 0
			reg = true
			script:RegisterEvent(EVENT_FRAME, Tick)
			script:RegisterEvent(EVENT_KEY, Key)
			script:UnregisterEvent(Load)
		end
	end	
end

function Close()
	if reg then
		incoming_projectiles = {} 
		incoming_damage = 0
		testedIncomingDamage = 0
		script:UnregisterEvent(Tick)
		script:UnregisterEvent(Key)
		script:RegisterEvent(EVENT_TICK, Load)	
		reg = false
	end
end

script:RegisterEvent(EVENT_CLOSE, Close)
script:RegisterEvent(EVENT_TICK, Load)
