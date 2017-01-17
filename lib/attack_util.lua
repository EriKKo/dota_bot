local GeometryUtil = require(GetScriptDirectory() .. "/lib/geometry_util")

local attackData = {}

local function GetDPS(source, target, sourceLocation, targetLocation)
  sourceLocation = sourceLocation or source:GetLocation()
  targetLocation = targetLocation or target:GetLocation()
  
  local dps = target:GetActualDamage(source:GetAttackDamage() / source:GetSecondsPerAttack(), DAMAGE_TYPE_PHYSICAL)
  dps = math.min(1, dps / target:GetHealth())
  if GetHeightLevel(sourceLocation) > GetHeightLevel(targetLocation) then
    -- Source has lowground
    dps = 0.75 * dps
  end
  return dps
end

local function GetAttackRange(source, target)
  local attackRange = source:GetAttackRange()
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
  local dist = GeometryUtil.GetLocationToLocationDistance(sourceLocation, targetLocation)
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
      threat = math.min(1, threat + GetThreat(source, target, nil, targetLocation))
    end
  end
  return threat
end

local function GetAttackData(bot)
  local data = attackData[bot]
  if not data then
    data = {
      attackStartTime = 0
    }
    attackData[bot] = data
  end
  return data
end

local function GetProbableLocation(unit, deltaTime)
  return unit:GetLocation() + unit:GetExtrapolatedLocation(deltaTime) * unit:GetMovementDirectionStability()
end

local function FaceLocation(bot, location)
  bot:Action_MoveToLocation(GeometryUtil.GetLocationAlongLine(bot:GetLocation(), location, 1))
  bot:Action_ClearActions(false)
end

local function GetAttackCooldown(bot)
  return math.max(0, bot:GetLastAttackTime() + bot:GetSecondsPerAttack() - bot:GetAttackPoint() / bot:GetAttackSpeed() - GameTime())
end

local function CanAttack(bot)
  return GetAttackCooldown(bot) <= 0
end

local function Attack(bot, target)
  local data = GetAttackData(bot)
  local actionType = bot:GetCurrentActionType()
  if CanAttack(bot) then
    if actionType ~= BOT_ACTION_TYPE_ATTACK or bot:GetAttackTarget() ~= target or bot:GetLastAttackTime() > data.attackStartTime then
      -- Start new attack
      if GetUnitToUnitDistance(bot, target) <= GetAttackRange(bot, target) then
        bot:Action_AttackUnit(target, true)
        data.attackStartTime = GameTime()
      else
        bot:Action_MoveToLocation(target:GetLocation())
      end
    end
  end
end

local function IsAttacking(bot)
  local data = GetAttackData(bot)
  return bot:GetCurrentActionType() == BOT_ACTION_TYPE_ATTACK and data.attackStartTime >= bot:GetLastAttackTime()
end

return {
  Attack = Attack,
  CanAttack = CanAttack,
  FaceLocation = FaceLocation,
  GetAttackCooldown = GetAttackCooldown,
  GetAttackRange = GetAttackRange,
  GetDPS = GetDPS,
  GetProbableLocation = GetProbableLocation,
  GetThreat = GetThreat,
  GetThreatFromSources = GetThreatFromSources,
  GetThreatRange = GetThreatRange,
  IsAttacking = IsAttacking
}