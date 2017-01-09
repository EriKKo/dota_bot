local GeometryUtil = require(GetScriptDirectory() .. "/lib/geometry_util")

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
local ADDED_THREAT_RANGE = 400
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

local function GetThreatRange(unit)
  local attackRange = unit:GetAttackRange()
  if unit:IsTower() then
    attackRange = TOWER_ATTACK_RANGE
  elseif unit:IsCreep() and CREEP_ATTACK_RANGES[unit:GetUnitName()] then
    attackRange = CREEP_ATTACK_RANGES[unit:GetUnitName()]
  elseif attackRange == -1 then
    attackRange = DEFAULT_ATTACK_RANGE
  end
  return attackRange + ADDED_THREAT_RANGE
end

local function GetThreat(source, target, sourceLocation, targetLocation)
  sourceLocation = sourceLocation or source:GetLocation()
  targetLocation = targetLocation or target:GetLocation()
  local dps = GetDPS(source, target, sourceLocation, targetLocation)
  local dist = #(sourceLocation - targetLocation)
  local threatRange = GetThreatRange(source)
  return math.max(0, dps * math.min(ADDED_THREAT_RANGE, threatRange - dist) / ADDED_THREAT_RANGE)
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

return {
  GetDPS = GetDPS,
  GetThreatRange = GetThreatRange,
  GetThreat = GetThreat,
  GetThreatFromSources = GetThreatFromSources
}