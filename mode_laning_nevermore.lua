
local util = require(GetScriptDirectory().."/lib/util")

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
local HERO_ATTACK_RANGE = 600
local TOWER_THREAT_RANGE = 900
local MAX_SEARCH_RADIUS = 1600
local LASTHIT_THREAT_THRESHOLD = 1.5
local LOCATION_NOISE = 100
local LANE_RADIUS = 900
local EXPERIENCE_RADIUS = 1200
local CREEP_CLOSE_RANGE = 200
local LOW_CREEP_HP_MAX = 200
local INFINITY = 1000000
local LASTHIT_DURATION = 0.8

local AGGRESSIVENESS = 0.5
local LOW_ENEMY_CREEP_IN_RANGE_SCORE = 0.3
local ENEMY_CREEP_IN_EXP_RANGE_SCORE = 0
local ALLIED_CREEP_CLOSE_SCORE = -0.5

local laneData = {
  allyCreeps = {},
  enemyCreeps = {},
  allyHeroes = {},
  enemyHeroes = {},
  allyTowers = {},
  enemyTowers = {}
}
local aggroData = {}
local distanceToClosestTarget = {}
local creepHealth = {}
local creepDamageHistory = {}

function CalculateLaneData(bot)
  laneData.allyCreeps = bot:GetNearbyCreeps(MAX_SEARCH_RADIUS, false)
  laneData.enemyCreeps = bot:GetNearbyCreeps(MAX_SEARCH_RADIUS, true)
  laneData.allyHeroes = bot:GetNearbyHeroes(MAX_SEARCH_RADIUS, false, BOT_MODE_NONE)
  laneData.allyHeroes = util.Filter(laneData.allyHeroes, function(hero) return hero ~= bot end) -- Filter out our own hero
  laneData.enemyHeroes = bot:GetNearbyHeroes(MAX_SEARCH_RADIUS, true, BOT_MODE_NONE)
  laneData.allyTowers = bot:GetNearbyTowers(MAX_SEARCH_RADIUS, false)
  laneData.enemyTowers = bot:GetNearbyTowers(MAX_SEARCH_RADIUS, true)
  
  local gameTime = GameTime()
  local newCreepDamageHistory = {}
  function update(creeps)
    for _,creep in ipairs(creeps) do
      local newHealth = creep:GetHealth()
      local oldHealth = creepHealth[creep] or newHealth
      creepHealth[creep] = newHealth
      local damageHistory = creepDamageHistory[creep] or util.Deque()
      if newHealth < oldHealth then
        damageHistory.AddLast({damage = oldHealth - newHealth, time = gameTime})
      end
      while damageHistory.PeekFirst() and gameTime - damageHistory.PeekFirst().time > LASTHIT_DURATION do
        damageHistory.PollFirst()
      end
      newCreepDamageHistory[creep] = damageHistory
    end
  end
  update(laneData.allyCreeps)
  update(laneData.enemyCreeps)
  creepDamageHistory = newCreepDamageHistory
  
  aggroData = {}
  distanceToClosestTarget = {}
  function CalculateAggro(sourceGroup, targetGroups)
    for _,source in ipairs(sourceGroup) do
      local closestTarget = nil
      distanceToClosestTarget[source] = INFINITY
      for _,targetGroup in ipairs(targetGroups) do
        for _,target in ipairs(targetGroup) do
          local dist = GetUnitToUnitDistance(source, target)
          if dist < math.min(GetThreatRange(source), distanceToClosestTarget[source]) then
            closestTarget = target
            distanceToClosestTarget[source] = dist
          end
        end
      end
      if closestTarget then
        aggroData[closestTarget] = (aggroData[closestTarget] or 0) + GetThreat(source, closestTarget)
      end
    end
  end
  CalculateAggro(laneData.allyCreeps, {laneData.enemyCreeps, laneData.enemyHeroes})
  CalculateAggro(laneData.allyTowers, {laneData.enemyCreeps, laneData.enemyHeroes})
  CalculateAggro(laneData.enemyCreeps, {laneData.allyCreeps, {bot}})
  CalculateAggro(laneData.enemyTowers, {laneData.allyCreeps, {bot}})
end

function GetThreat(source, target, sourceLocation, targetLocation)
  sourceLocation = sourceLocation or source:GetLocation()
  targetLocation = targetLocation or target:GetLocation()
  local threat = 0
  
  if source:IsTower() then
    threat = target:GetActualDamage(TOWER1_DPS, DAMAGE_TYPE_PHYSICAL)
  elseif source:IsCreep() and CREEP_DPS[source:GetUnitName()] then
    threat = target:GetActualDamage(CREEP_DPS[source:GetUnitName()], DAMAGE_TYPE_PHYSICAL)
  else
    threat = source:GetEstimatedDamageToTarget(false, target, 1, DAMAGE_TYPE_PHYSICAL)
  end
  if threat < 0 then
    print(source:GetUnitName(), threat)
  end
  threat = threat / target:GetHealth()
  if GetHeightLevel(sourceLocation) > GetHeightLevel(targetLocation) then
    -- Source has lowground
    threat = 0.75 * threat
  end
  return threat
end

function GetThreatRange(unit)
  if unit:IsTower() then
    return TOWER_THREAT_RANGE
  elseif unit:IsCreep() and CREEP_THREAT_RANGES[unit:GetUnitName()] then
    return CREEP_THREAT_RANGES[unit:GetUnitName()]
  else
    return HERO_THREAT_RANGE
  end
end

function GetFountainLocation(enemy)
  if GetTeam() == TEAM_RADIANT and not enemy or GetTeam() == TEAM_DIRE and enemy then
    return Vector(-7000, -7000, 0)
  else
    return Vector(7000, 7000, 0)
  end
end

function GetLocationToLocationDistance(l1, l2)
  return math.sqrt((l1[1] - l2[1])*(l1[1] - l2[1]) + (l1[2] - l2[2])*(l1[2] - l2[2]))
end

function GetFrontLineLocation(bot)
  local ownFountain = GetFountainLocation()
  local enemyFountain = GetFountainLocation(true)
  local minLocation = ownFountain
  local maxLocation = enemyFountain
  -- Use the front tower as front line if creeps are not there yet
  for _,allyTower in ipairs(laneData.allyTowers) do
    local towerSafetyLocation = allyTower:GetLocation()
    if GetLocationToLocationDistance(towerSafetyLocation, ownFountain) > GetLocationToLocationDistance(minLocation, ownFountain) then
      minLocation = towerSafetyLocation
    end
  end
  -- Make sure we don't towerdive
  for _,enemyTower in ipairs(laneData.enemyTowers) do
    local towerLocation = enemyTower:GetLocation()
    local homeDirection = Vector(ownFountain[1] - towerLocation[1], ownFountain[2] - towerLocation[2])
    local sum = homeDirection[1] + homeDirection[2]
    homeDirection[1] = homeDirection[1] / sum
    homeDirection[2] = homeDirection[2] / sum
    local beforeTowerLocation = Vector(towerLocation[1] + homeDirection[1] * TOWER_THREAT_RANGE, towerLocation[2] + homeDirection[2] * TOWER_THREAT_RANGE, 0)
    if GetLocationToLocationDistance(beforeTowerLocation, ownFountain) < GetLocationToLocationDistance(maxLocation, ownFountain) then
      maxLocation = beforeTowerLocation
    end
  end
  local frontLineLocation = nil
  if #laneData.allyCreeps > 0 then
    frontLineLocation = Vector(0, 0, 0)
    for _,creep in ipairs(laneData.allyCreeps) do
      local loc = creep:GetLocation()
      frontLineLocation[1] = frontLineLocation[1] + loc[1]
      frontLineLocation[2] = frontLineLocation[2] + loc[2]
      frontLineLocation[3] = frontLineLocation[3] + loc[3]
    end
    frontLineLocation[1] = frontLineLocation[1] / #laneData.allyCreeps
    frontLineLocation[2] = frontLineLocation[2] / #laneData.allyCreeps
    frontLineLocation[3] = frontLineLocation[3] / #laneData.allyCreeps
  else
    local front = 0.55 -- Should be based on the front tower
    for p = 1,front,-0.01 do
      local location = GetLocationAlongLane(bot:GetAssignedLane(), p)
      local alliedCreeps = bot:FindAoELocation(false, false, location, 0, 500, 0, INFINITY).count
      -- TODO Get position of the frontline tower
      if alliedCreeps > 1 then
        front = p
        break
      end
    end
    frontLineLocation = GetLocationAlongLane(bot:GetAssignedLane(), front - 0.07)
  end
  if GetLocationToLocationDistance(frontLineLocation, ownFountain) < GetLocationToLocationDistance(minLocation, ownFountain) then
    return minLocation
  elseif GetLocationToLocationDistance(frontLineLocation, ownFountain) > GetLocationToLocationDistance(maxLocation, ownFountain) then
    return maxLocation
  else
    return frontLineLocation
  end
end

function GetLaneLocationScore(bot, botLocation)
  botLocation = botLocation or bot:GetLocation()
  local score = -GetIncomingThreat(bot, botLocation)
  for _,enemyCreep in ipairs(laneData.enemyCreeps) do
    if GetUnitToLocationDistance(enemyCreep, botLocation) < HERO_ATTACK_RANGE and enemyCreep:GetHealth() < LOW_CREEP_HP_MAX then
      score = score + LOW_ENEMY_CREEP_IN_RANGE_SCORE
    end
    if GetUnitToLocationDistance(enemyCreep, botLocation) < EXPERIENCE_RADIUS then
      score = score + ENEMY_CREEP_IN_EXP_RANGE_SCORE
    end
  end
  for _,allyCreep in ipairs(laneData.allyCreeps) do
    if GetUnitToLocationDistance(allyCreep, botLocation) < CREEP_CLOSE_RANGE then
      score = score + ALLIED_CREEP_CLOSE_SCORE
    end
  end
  return score
end

function GetIncomingThreat(bot, botLocation)
  botLocation = botLocation or bot:GetLocation()
  local threat = 0
  function ThreatFromUnits(units)
    for _,unit in ipairs(units) do
      if GetUnitToLocationDistance(unit, botLocation) < GetThreatRange(unit) then
        threat = threat + GetThreat(unit, bot, nil, botLocation)
      end
      if GetUnitToLocationDistance(unit, botLocation) < (distanceToClosestTarget[unit] or 0) then
        threat = threat + GetThreat(unit, bot, nil, botLocation)
      end
    end
  end
  ThreatFromUnits(laneData.enemyCreeps)
  ThreatFromUnits(laneData.enemyTowers)
  ThreatFromUnits(laneData.enemyHeroes)
  return threat
end

function GetHeroThreatScore(bot, botLocation)
  botLocation = botLocation or bot:GetLocation()
  local incomingThreat = GetIncomingThreat(bot, botLocation)
  local outgoingThreat = 0
  
  for _,enemyHero in ipairs(laneData.enemyHeroes) do
    if GetUnitToLocationDistance(enemyHero, botLocation) < GetThreatRange(enemyHero) then
      local outgoingHeroThreat = (GetThreat(bot, enemyHero, botLocation) + (aggroData[enemyHero] or 0)) * AGGRESSIVENESS
      outgoingThreat = math.max(outgoingThreat, outgoingHeroThreat)
    end
  end
  
  local score = 0
  if outgoingThreat ~= 0 and incomingThreat ~= 0 then
    if outgoingThreat > incomingThreat then
      score = outgoingThreat / incomingThreat - 1
    else
      score = -(incomingThreat / outgoingThreat - 1)
    end
  end
  return score
end

function GetLastHitTarget(bot, enemy)
  local creeps = enemy and laneData.enemyCreeps or laneData.allyCreeps
  for _,creep in ipairs(creeps) do
    if GetUnitToUnitDistance(creep, bot) < HERO_ATTACK_RANGE and (enemy or creep:GetHealth() < creep:GetMaxHealth() / 2) then
      local damage = 0
      local damageHistory = creepDamageHistory[creep]
      -- TODO should ignore damage done be the bot itself during this period
      for i = damageHistory.first,damageHistory.last do
        damage = damage + damageHistory[i].damage
      end
      damage = damage + bot:GetEstimatedDamageToTarget(false, creep, LASTHIT_DURATION, DAMAGE_TYPE_PHYSICAL)
      if damage >= creep:GetHealth() then
        return creep
      end
    end
  end
end

function Think()
  
  function f()
    local bot = GetBot()
    CalculateLaneData(bot)
    local l = GetFountainLocation()
    print(GetLaneLocationScore(bot), GetHeroThreatScore(bot))
    
    if not bot:IsUsingAbility() then
      -- Look for an enemy creep to attack
      local attackTarget = GetLastHitTarget(bot, true)
      
      -- Look for an allied creep to deny
      if not attackTarget then
        attackTarget = GetLastHitTarget(bot, false)
      end
      
      if attackTarget then
        print("Attacking " .. attackTarget:GetUnitName())
        bot:Action_AttackUnit(attackTarget, false)
      else
        local frontLineLocation = GetFrontLineLocation(bot)
        frontLineLocation[1] = frontLineLocation[1] + RandomFloat(0, LOCATION_NOISE)
        frontLineLocation[2] = frontLineLocation[2] + RandomFloat(0, LOCATION_NOISE)
        local bestLocation = frontLineLocation
        for r = 0.2, 1 ,0.2 do
          for a = 0, 2*math.pi, 2*math.pi / 12 do
            local x = math.cos(a) * r * LANE_RADIUS
            local y = math.sin(a) * r * LANE_RADIUS
            local location = Vector(frontLineLocation[1] + x, frontLineLocation[2] + y, frontLineLocation[3])
            if IsLocationPassable(location) and GetLaneLocationScore(bot, location) > GetLaneLocationScore(bot, bestLocation) then
              bestLocation = location
            end
          end
        end
        local locationChangeScore = GetLaneLocationScore(bot, bestLocation) - GetLaneLocationScore(bot)
        local harassScore = GetHeroThreatScore(bot)
        --print(locationChangeScore, harassScore)
        if locationChangeScore >= harassScore then
          -- TODO if score too low change facing instead
          print("Moving")
          bot:Action_MoveToLocation(bestLocation)
        else
          print("Harassing")
          for _,enemyHero in ipairs(laneData.enemyHeroes) do
            local dist = GetUnitToUnitDistance(bot, enemyHero)
            if dist < HERO_ATTACK_RANGE then
              bot:Action_AttackUnit(enemyHero, false)
              break
            elseif dist < HERO_THREAT_RANGE then
              bot:Action_MoveToLocation(enemyHero:GetLocation())
            end
          end
        end
      end
    end
  end
  local status, err = pcall(f)
  if not status then
    print(err)
  end
end

function GetDesire()
  return 0.9
end