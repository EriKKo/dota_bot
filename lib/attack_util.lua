local GeometryUtil = require(GetScriptDirectory() .. "/lib/geometry_util")

local attackData = {}

local CREEP_DPS = {
  npc_dota_creep_goodguys_melee = 21,
  npc_dota_creep_badguys_melee = 21,
  npc_dota_creep_goodguys_ranged = 24,
  npc_dota_creep_badguys_ranged = 24,
  npc_dota_goodguys_siege = 15,
  npc_dota_badguys_siege = 15
}
local TOWER1_DPS = 110
-- TODO Add mega creeps
local CREEP_ATTACK_RANGES = {
  npc_dota_creep_goodguys_melee = 100,
  npc_dota_creep_badguys_melee = 100,
  npc_dota_creep_goodguys_ranged = 500,
  npc_dota_creep_badguys_ranged = 500,
  npc_dota_goodguys_siege = 690,
  npc_dota_badguys_siege = 690
}
local TOWER_ATTACK_RANGE = 700
local DEFAULT_ATTACK_RANGE = 500

local function GetDPS(source, target, sourceLocation, targetLocation)
  sourceLocation = sourceLocation or source:GetLocation()
  targetLocation = targetLocation or target:GetLocation()
  local dps = 0
  
  if source:IsTower() then
    dps = target:GetActualDamage(TOWER1_DPS, DAMAGE_TYPE_PHYSICAL)
  elseif source:IsCreep() and CREEP_DPS[source:GetUnitName()] then
    dps = target:GetActualDamage(CREEP_DPS[source:GetUnitName()], DAMAGE_TYPE_PHYSICAL)
  else
    dps = source:GetEstimatedDamageToTarget(false, target, 1, DAMAGE_TYPE_PHYSICAL)
  end
  dps = dps / target:GetHealth()
  if GetHeightLevel(sourceLocation) > GetHeightLevel(targetLocation) then
    -- Source has lowground
    dps = 0.75 * dps
  end
  return dps
end

local function GetAttackRange(source, target)
  local attackRange = source:GetAttackRange()
  if attackRange == -1 then
    if source:IsTower() then
      attackRange = TOWER_ATTACK_RANGE
    elseif source:IsCreep() and CREEP_ATTACK_RANGES[source:GetUnitName()] then
      attackRange = CREEP_ATTACK_RANGES[source:GetUnitName()]
    else
      attackRange = DEFAULT_ATTACK_RANGE
    end
  end
  attackRange = attackRange + source:GetBoundingRadius()
  if target then
    attackRange = attackRange + target:GetBoundingRadius()
  end
  return attackRange
end

local function GetThreatRange(source, target)
  return GetAttackRange(source, target) + source:GetCurrentMovementSpeed()
end

local function GetThreat(source, target, sourceLocation, targetLocation)
  sourceLocation = sourceLocation or source:GetLocation()
  targetLocation = targetLocation or target:GetLocation()
  local dps = GetDPS(source, target, sourceLocation, targetLocation)
  local dist = #(sourceLocation - targetLocation)
  local attackRange = GetAttackRange(source, target)
  local threatRange = GetThreatRange(source, target)
  if dist <= attackRange then
    return dps
  elseif dist <= threatRange then
    return dps * (threatRange - dist) / (threatRange - attackRange)
  else
    return 0
  end
end

local function GetThreatFromSources(target, targetLocation, sourceGroups)
  targetLocation = targetLocation or target:GetLocation()
  local threat = 0
  for _,sourceGroup in ipairs(sourceGroups) do
    for _,source in ipairs(sourceGroup) do
      threat = threat + GetThreat(source, target, nil, targetLocation)
    end
  end
  return threat
end

local function GetAttackData(bot)
  local data = attackData[bot]
  if not data then
    data = {
      attackStartTime = 0,
      attackReadyTime = 0
    }
    attackData[bot] = data
  end
  return data
end

local function FaceLocation(bot, location)
  bot:Action_MoveToLocation(GeometryUtil.GetLocationAlongLine(bot:GetLocation(), location, 1))
  bot:Action_ClearActions(false)
end

local function Attack(bot, target)
  local data = GetAttackData(bot)
  local actionType = bot:GetCurrentActionType()
  if GameTime() >= data.attackReadyTime then
    -- Can attack
    if actionType ~= BOT_ACTION_TYPE_ATTACK or bot:GetAttackTarget() ~= target or data.attackReadyTime > data.attackStartTime then
      -- Start new attack
      if GetUnitToUnitDistance(bot, target) <= GetAttackRange(bot, target) then
        bot:Action_AttackUnit(target, true)
        data.attackStartTime = GameTime()
      else
        bot:Action_MoveToLocation(target:GetLocation())
      end
    else
      -- Continue attack
      local animationPoint = GameTime() - data.attackStartTime
      if animationPoint >= bot:GetAttackPoint() / bot:GetAttackSpeed() then
        data.attackReadyTime = data.attackStartTime + bot:GetSecondsPerAttack()
      end
    end
  else
    -- Can't attack, move instead
    bot:Action_MoveToLocation(GeometryUtil.GetLocationAlongLine(target:GetLocation(), bot:GetLocation(), GetAttackRange(bot, target)))
  end
end

local function IsAttacking(bot)
  local data = GetAttackData(bot)
  return bot:GetCurrentActionType() == BOT_ACTION_TYPE_ATTACK and data.attackStartTime >= data.attackReadyTime
end

local function CanAttack(bot)
  local data = GetAttackData(bot)
  return GameTime() >= data.attackReadyTime
end

return {
  Attack = Attack,
  CanAttack = CanAttack,
  FaceLocation = FaceLocation,
  GetAttackRange = GetAttackRange,
  GetDPS = GetDPS,
  GetThreat = GetThreat,
  GetThreatFromSources = GetThreatFromSources,
  GetThreatRange = GetThreatRange,
  IsAttacking = IsAttacking
}