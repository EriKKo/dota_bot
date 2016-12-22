local geometry = require(GetScriptDirectory() .. "/lib/geometry")

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
local CREEP_THREAT_RANGES = {
  npc_dota_creep_goodguys_melee = 200,
  npc_dota_creep_badguys_melee = 200,
  npc_dota_creep_goodguys_ranged = 600,
  npc_dota_creep_badguys_ranged = 600,
  npc_dota_goodguys_siege = 600,
  npc_dota_badguys_siege = 600
}
local HERO_THREAT_RANGE = 900
local TOWER_THREAT_RANGE = 900

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
  if unit:IsTower() then
    return TOWER_THREAT_RANGE
  elseif unit:IsCreep() and CREEP_THREAT_RANGES[unit:GetUnitName()] then
    return CREEP_THREAT_RANGES[unit:GetUnitName()]
  else
    return HERO_THREAT_RANGE
  end
end

local function GetThreat(source, target, sourceLocation, targetLocation)
  sourceLocation = sourceLocation or source:GetLocation()
  targetLocation = targetLocation or target:GetLocation()
  local dps = GetDPS(source, target, sourceLocation, targetLocation)
  local dist = geometry.GetLocationToLocationDistance(sourceLocation, targetLocation)
  local threatRange = GetThreatRange(source)
  if dist > threatRange then
    return 0
  else
    return (1 + (threatRange - dist)/threatRange) * dps
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

return {
  GetDPS = GetDPS,
  GetThreatRange = GetThreatRange,
  GetThreat = GetThreat,
  GetThreatFromSources = GetThreatFromSources
}