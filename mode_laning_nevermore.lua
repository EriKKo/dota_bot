local Deque = require(GetScriptDirectory() .. "/lib/deque").Deque
local threat = require(GetScriptDirectory() .. "/lib/threat")
local geometry = require(GetScriptDirectory() .. "/lib/geometry")

local HERO_ATTACK_RANGE = 600
local MAX_SEARCH_RADIUS = 1600
local LOCATION_NOISE = 100
local LANE_RADIUS = 900
local EXPERIENCE_RADIUS = 1200
local CREEP_CLOSE_RANGE = 200
local LOW_CREEP_HP_MAX = 200
local INFINITY = 1000000
local LASTHIT_DURATION = 0.8

local AGGRESSIVENESS = 1
local LOW_ENEMY_CREEP_IN_RANGE_SCORE = 0.02
local ENEMY_CREEP_IN_EXP_RANGE_SCORE = 0
local CREEP_CLOSE_SCORE = -0.01

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
      local damageHistory = creepDamageHistory[creep] or Deque()
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
          if dist < math.min(threat.GetThreatRange(source), distanceToClosestTarget[source]) then
            closestTarget = target
            distanceToClosestTarget[source] = dist
          end
        end
      end
      if closestTarget then
        aggroData[closestTarget] = (aggroData[closestTarget] or 0) + threat.GetDPS(source, closestTarget)
      end
    end
  end
  CalculateAggro(laneData.allyCreeps, {laneData.enemyCreeps, laneData.enemyHeroes})
  CalculateAggro(laneData.allyTowers, {laneData.enemyCreeps, laneData.enemyHeroes})
  CalculateAggro(laneData.enemyCreeps, {laneData.allyCreeps, {bot}})
  CalculateAggro(laneData.enemyTowers, {laneData.allyCreeps, {bot}})
end

function GetFrontLineLocation(bot)
  local ownFountain = geometry.GetFountainLocation()
  local enemyFountain = geometry.GetFountainLocation(true)
  local minLocation = ownFountain
  local maxLocation = enemyFountain
  -- Use the front tower as front line if creeps are not there yet
  for _,allyTower in ipairs(laneData.allyTowers) do
    local towerSafetyLocation = allyTower:GetLocation()
    if geometry.GetLocationToLocationDistance(towerSafetyLocation, ownFountain) > geometry.GetLocationToLocationDistance(minLocation, ownFountain) then
      minLocation = towerSafetyLocation
    end
  end
  -- Make sure we don't towerdive
  for _,enemyTower in ipairs(laneData.enemyTowers) do
    local beforeTowerLocation = geometry.MoveAlongLine(enemyTower:GetLocation(), ownFountain, threat.GetThreatRange(enemyTower))
    if geometry.GetLocationToLocationDistance(beforeTowerLocation, ownFountain) < geometry.GetLocationToLocationDistance(maxLocation, ownFountain) then
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
  if geometry.GetLocationToLocationDistance(frontLineLocation, ownFountain) < geometry.GetLocationToLocationDistance(minLocation, ownFountain) then
    return minLocation
  elseif geometry.GetLocationToLocationDistance(frontLineLocation, ownFountain) > geometry.GetLocationToLocationDistance(maxLocation, ownFountain) then
    return maxLocation
  else
    return frontLineLocation
  end
end

function GetLaneLocationScore(bot, botLocation)
  botLocation = botLocation or bot:GetLocation()
  local score = -threat.GetThreatFromSources(bot, botLocation, {laneData.enemyCreeps, laneData.enemyHeroes, laneData.enemyTowers})
  for _,enemyCreep in ipairs(laneData.enemyCreeps) do
    if GetUnitToLocationDistance(enemyCreep, botLocation) < HERO_ATTACK_RANGE and enemyCreep:GetHealth() < LOW_CREEP_HP_MAX then
      score = score + LOW_ENEMY_CREEP_IN_RANGE_SCORE
    end
    if GetUnitToLocationDistance(enemyCreep, botLocation) < EXPERIENCE_RADIUS then
      score = score + ENEMY_CREEP_IN_EXP_RANGE_SCORE
    end
    if GetUnitToLocationDistance(enemyCreep, botLocation) < CREEP_CLOSE_RANGE then
      score = score + CREEP_CLOSE_SCORE
    end
  end
  for _,allyCreep in ipairs(laneData.allyCreeps) do
    if GetUnitToLocationDistance(allyCreep, botLocation) < CREEP_CLOSE_RANGE then
      score = score + CREEP_CLOSE_SCORE
    end
  end
  return score
end

function GetHarassTarget(bot)
  local harassTarget = nil
  local harassScore = -INFINITY
  
  for _,enemyHero in ipairs(laneData.enemyHeroes) do
    local harassLocation = bot:GetLocation()
    if GetUnitToUnitDistance(bot, enemyHero) > HERO_ATTACK_RANGE then
      harassLocation = geometry.MoveAlongLine(enemyHero:GetLocation(), bot:GetLocation(), HERO_ATTACK_RANGE)
    end
    local incomingThreat = threat.GetThreatFromSources(bot, harassLocation, {laneData.enemyCreeps, laneData.enemyHeroes, laneData.enemyTowers})
    local outgoingThreat = threat.GetThreatFromSources(enemyHero, nil, {laneData.allyCreeps, laneData.allyHeroes, laneData.allyTowers}) * AGGRESSIVENESS
    local score = -INFINITY
    if outgoingThreat ~= 0 and incomingThreat ~= 0 then
      if outgoingThreat > incomingThreat then
        score = outgoingThreat / incomingThreat - 1
      else
        score = -(incomingThreat / outgoingThreat - 1)
      end
    end
    if score > harassScore then
      harassTarget = enemyHero
      harassScore = score
    end
  end
  
  return harassTarget, harassScore
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
    
    if not bot:IsUsingAbility() then
      -- Look for an enemy creep to attack
      local attackTarget = GetLastHitTarget(bot, true)
      
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
        local locationChangeScore = GetLaneLocationScore(bot, bestLocation) - GetLaneLocationScore(bot)
        local harassTarget, harassScore = GetHarassTarget(bot)
        --print(locationChangeScore, harassScore)
        if locationChangeScore > harassScore then
          -- TODO if score too low change facing instead
          bot:Action_MoveToLocation(bestLocation)
        else
          if GetUnitToUnitDistance(bot, harassTarget) < HERO_ATTACK_RANGE then
            bot:Action_AttackUnit(harassTarget, false)
          else
            bot:Action_MoveToLocation(harassTarget:GetLocation())
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