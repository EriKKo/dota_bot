
require(GetScriptDirectory().."/util")

local CREEP_DPS = {
  npc_dota_creep_goodguys_melee = 21,
  npc_dota_creep_badguys_melee = 21,
  npc_dota_creep_goodguys_ranged = 24,
  npc_dota_creep_badguys_ranged = 24,
  npc_dota_goodguys_siege = 15,
  npc_dota_badguys_siege = 15
}
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

local AGGRESSIVENESS = -2
local LOW_ENEMY_CREEP_IN_RANGE_SCORE = 1.5
local ENEMY_CREEP_IN_RANGE_SCORE = 1
local ALLIED_CREEP_CLOSE_SCORE = -0.5
local ENEMY_CREEP_CLOSE_SCORE = -1
local ENEMY_CREEP_AGGRO_SCORE = -1
local IN_RANGE_OF_ENEMY_TOWER_SCORE = -7

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

function CalculateLaneData(bot)
  laneData.allyCreeps = bot:GetNearbyCreeps(MAX_SEARCH_RADIUS, false)
  laneData.enemyCreeps = bot:GetNearbyCreeps(MAX_SEARCH_RADIUS, true)
  laneData.allyHeroes = bot:GetNearbyHeroes(MAX_SEARCH_RADIUS, false, BOT_MODE_NONE)
  laneData.allyHeroes = Filter(laneData.allyHeroes, function(hero) return hero ~= bot end) -- Filter out our own hero
  laneData.enemyHeroes = bot:GetNearbyHeroes(MAX_SEARCH_RADIUS, true, BOT_MODE_NONE)
  laneData.allyTowers = bot:GetNearbyTowers(MAX_SEARCH_RADIUS, false)
  laneData.enemyTowers = bot:GetNearbyTowers(MAX_SEARCH_RADIUS, true)
  
  aggroData = {}
  distanceToClosestTarget = {}
  -- Guess aggro of ally creeps
  for _,allyCreep in ipairs(laneData.allyCreeps) do
    local closestTarget = nil
    distanceToClosestTarget[allyCreep] = INFINITY
    for _,enemyCreep in ipairs(laneData.enemyCreeps) do
      local dist = GetUnitToUnitDistance(allyCreep, enemyCreep)
      if dist < math.min(GetThreatRange(allyCreep), distanceToClosestTarget[allyCreep]) then
        closestTarget = enemyCreep
        distanceToClosestTarget[allyCreep] = dist
      end
    end
    for _,enemyHero in ipairs(laneData.enemyHeroes) do
      local dist = GetUnitToUnitDistance(allyCreep, enemyHero)
      if dist < math.min(GetThreatRange(allyCreep), distanceToClosestTarget[allyCreep]) then
        closestTarget = enemyHero
        distanceToClosestTarget[allyCreep] = dist
      end
    end
    if closestTarget then
      aggroData[closestTarget] = (aggroData[closestTarget] or 0) + GetThreat(allyCreep, closestTarget)
    end
  end
  
  -- Guess aggro of enemy creeps
  for _,enemyCreep in ipairs(laneData.enemyCreeps) do
    local closestTarget = nil
    distanceToClosestTarget[enemyCreep] = INFINITY
    for _,allyCreep in ipairs(laneData.allyCreeps) do
      local dist = GetUnitToUnitDistance(enemyCreep, allyCreep)
      if dist < math.min(GetThreatRange(enemyCreep), distanceToClosestTarget[enemyCreep]) then
        closestTarget = allyCreep
        distanceToClosestTarget[enemyCreep] = dist
      end
    end
    local dist = GetUnitToUnitDistance(enemyCreep, bot)
    if dist < math.min(GetThreatRange(enemyCreep), distanceToClosestTarget[enemyCreep]) then
      closestTarget = bot
      distanceToClosestTarget[enemyCreep] = dist
    end
    if closestTarget then
      aggroData[closestTarget] = (aggroData[closestTarget] or 0) + GetThreat(enemyCreep, closestTarget)
    end
  end
end

function GetThreat(source, target, sourceLocation, targetLocation)
  sourceLocation = sourceLocation or source:GetLocation()
  targetLocation = targetLocation or target:GetLocation()
  local threat = 0
  if source:IsCreep() and CREEP_DPS[source:GetUnitName()] then
    threat = CREEP_DPS[source:GetUnitName()]
  else
    threat = source:GetEstimatedDamageToTarget(false, target, 1, DAMAGE_TYPE_PHYSICAL)
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

function GetFrontLineLocation(bot)
  if #laneData.allyCreeps > 0 then
    local location = Vector(0, 0, 0)
    for _,creep in ipairs(laneData.allyCreeps) do
      local loc = creep:GetLocation()
      location[1] = location[1] + loc[1]
      location[2] = location[2] + loc[2]
      location[3] = location[3] + loc[3]
    end
    location[1] = location[1] / #laneData.allyCreeps
    location[2] = location[2] / #laneData.allyCreeps
    location[3] = location[3] / #laneData.allyCreeps
    return location
  else
    local front = 0.55 -- Should be based on the front tower
    -- Should also be made to not towerdive
    for p = 1,front,-0.01 do
      local location = GetLocationAlongLane(bot:GetAssignedLane(), p)
      local alliedCreeps = bot:FindAoELocation(false, false, location, 0, 500, 0, INFINITY).count
      -- TODO Get position of the frontline tower
      if alliedCreeps > 1 then
        front = p
        break
      end
    end
    return GetLocationAlongLane(bot:GetAssignedLane(), front - 0.07)
  end
end

function GetLaneLocationScore(bot, botLocation)
  botLocation = botLocation or bot:GetLocation()
  local lowEnemyCreepsInRange = #Filter(laneData.enemyCreeps, function(creep) 
    return GetUnitToLocationDistance(creep, botLocation) < HERO_ATTACK_RANGE and creep:GetHealth() < LOW_CREEP_HP_MAX
  end)
  local enemyCreepsClose = #Filter(laneData.enemyCreeps, function(creep) 
    return GetUnitToLocationDistance(creep, botLocation) < CREEP_CLOSE_RANGE
  end)
  local enemyCreepsInRange = #Filter(laneData.enemyCreeps, function(creep) 
    return GetUnitToLocationDistance(creep, botLocation) < EXPERIENCE_RADIUS
  end)
  local allyCreepsClose = #Filter(laneData.allyCreeps, function(creep) 
    return GetUnitToLocationDistance(creep, botLocation) < CREEP_CLOSE_RANGE
  end)
  local enemyTowersInRange = #Filter(laneData.enemyTowers, function(tower) 
    return GetUnitToLocationDistance(tower, botLocation) < TOWER_THREAT_RANGE
  end)
  local enemyCreepAggro = 0
  for _,creep in ipairs(laneData.enemyCreeps) do
    if GetUnitToLocationDistance(creep, botLocation) < distanceToClosestTarget[creep] then
      enemyCreepAggro = enemyCreepAggro + 1
    end
  end
  local heroThreatScore = GetHeroThreatScore(bot, botLocation)
  if heroThreatScore ~= 0 then
    heroThreatScore = heroThreatScore + AGGRESSIVENESS
  end

  local score = lowEnemyCreepsInRange * LOW_ENEMY_CREEP_IN_RANGE_SCORE
  score = score + enemyCreepsClose * ENEMY_CREEP_CLOSE_SCORE
  score = score + enemyCreepsInRange * ENEMY_CREEP_IN_RANGE_SCORE
  score = score + allyCreepsClose * ALLIED_CREEP_CLOSE_SCORE
  score = score + enemyTowersInRange * IN_RANGE_OF_ENEMY_TOWER_SCORE
  score = score + enemyCreepAggro * ENEMY_CREEP_AGGRO_SCORE
  score = score + heroThreatScore
  return score
end

function GetHeroThreatScore(bot, botLocation)
  botLocation = botLocation or bot:GetLocation()
  local enemyHeroesInRange = Filter(laneData.enemyHeroes, function(hero)
      return GetUnitToLocationDistance(hero, botLocation) < GetThreatRange(hero)
    end)
  if #enemyHeroesInRange == 0 then
    return 0
  end
  local incomingThreat = 0
  local outgoingThreat = 0
  local enemyCreepsNearby = Filter(laneData.enemyCreeps, function(creep)
      return GetUnitToLocationDistance(creep, botLocation) < GetThreatRange(creep)
    end)
  for _,creep in ipairs(enemyCreepsNearby) do
    incomingThreat = incomingThreat + GetThreat(creep, bot, nil, botLocation)
  end
  local enemyTowersNearby = Filter(laneData.enemyTowers, function(tower)
      return GetUnitToLocationDistance(tower, botLocation) < GetThreatRange(tower)
    end)
  for _,tower in ipairs(enemyTowersNearby) do
    incomingThreat = incomingThreat + GetThreat(tower, bot, nil, botLocation)
  end
  
  for _,enemyHero in ipairs(enemyHeroesInRange) do
    incomingThreat = incomingThreat + GetThreat(enemyHero, bot, nil, botLocation)
    local outgoingHeroThreat = GetThreat(bot, enemyHero, botLocation)
    
    local allyCreepsNearEnemyHero = Filter(laneData.allyCreeps, function(creep)
        return GetUnitToUnitDistance(creep, hero) < GetThreatRange(creep)
      end)
    for _,creep in ipairs(allyCreepsNearEnemyHero) do
      outgoingHeroThreat = outgoingHeroThreat + GetThreat(creep, enemyHero)
    end
    
    local allyTowersNearEnemyHero = Filter(laneData.allyTowers, function(tower)
        return GetUnitToUnitDistance(tower, enemyHero) < GetThreatRange(tower)
      end)
    for _,tower in ipairs(allyTowersNearEnemyHero) do
      outgoingHeroThreat = outgoingHeroThreat + GetThreat(tower, enemyHero)
    end
    outgoingThreat = math.max(outgoingThreat, outgoingHeroThreat)
  end
  
  if outgoingThreat > incomingThreat then
    return outgoingThreat / incomingThreat - 1
  elseif incomingThreat > outgoingThreat then
    return -incomingThreat / outgoingThreat - 1
  else
    return 0
  end
end

function GetLastHitTarget(bot, enemy)
  local creeps = enemy and laneData.enemyCreeps or laneData.allyCreeps
  for _,creep in ipairs(creeps) do
    if GetUnitToUnitDistance(creep, bot) < HERO_ATTACK_RANGE then
      local creepThreat = (aggroData[creep] or 0) + GetThreat(bot, creep)
      if creepThreat > LASTHIT_THREAT_THRESHOLD then
        return creep
      end
    end
  end
end

function Think()
  
  function f()
    local bot = GetBot()
    CalculateLaneData(bot)
    --print("Aggro: "..(aggroData[bot] or 0))
    print(GetHeroThreatScore(bot))
    
    if not bot:IsUsingAbility() then
      -- Look for an enemy creep to attack
      local attackTarget = GetLastHitTarget(bot, true)
      
      -- Look for an enemy hero to harass
      if not attackTarget then
        local enemyHeroes = bot:GetNearbyHeroes(HERO_ATTACK_RANGE, true, BOT_MODE_NONE)
        for _,hero in ipairs(enemyHeroes) do
          if GetHeroThreatScore(bot) > 1 then
            attackTarget = hero
          end
        end
      end
      
      -- Look for an allied creep to deny
      if not attackTarget then
        attackTarget = GetLastHitTarget(bot, false)
      end
      if attackTarget then
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
        bot:Action_MoveToLocation(bestLocation)
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