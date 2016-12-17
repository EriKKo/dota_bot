
--require( GetScriptDirectory().."/util" )

-- Radiant creep names
-- "npc_dota_creep_goodguys_melee"
-- "npc_dota_creep_goodguys_ranged"
-- Dire creep names
-- "npc_dota_creep_badguys_melee"
-- "npc_dota_creep_badguys_ranged"

local MAX_SEARCH_RADIUS = 1600
local CREEP_ATTACK_DURATION = 1.7
local LOCATION_NOISE = 100
local LANE_RADIUS = 700
local EXPERIENCE_RADIUS = 1200
local CREEP_CLOSE_RANGE = 200
local TOWER_SAFETY_DISTANCE = 900
local ATTACK_CREEP_RANGE = 500
local LOW_CREEP_HP_MAX = 300
local INFINITY = 1000000

local LOW_ENEMY_CREEP_IN_RANGE_SCORE = 1.5
local ENEMY_CREEP_IN_RANGE_SCORE = 1
local ALLIED_CREEP_CLOSE_SCORE = -0.5
local ENEMY_CREEP_CLOSE_SCORE = -1
local IN_RANGE_OF_ENEMY_TOWER_SCORE = -7

function Filter(t, f)
  local res = {}
  for _,v in ipairs(t) do
    if f(v) then
      res[#res + 1] = v
    end
  end
  return res
end

function GetLaneData(bot)
  local laneData = {}
  laneData.allyCreeps = bot:GetNearbyCreeps(MAX_SEARCH_RADIUS, false)
  laneData.enemyCreeps = bot:GetNearbyCreeps(MAX_SEARCH_RADIUS, true)
  laneData.allyHeroes = bot:GetNearbyHeroes(MAX_SEARCH_RADIUS, false, BOT_MODE_NONE)
  laneData.allyHeroes = Filter(laneData.allyHeroes, function(hero) return hero ~= bot end) -- Filter out our own hero
  laneData.enemyHeroes = bot:GetNearbyHeroes(MAX_SEARCH_RADIUS, true, BOT_MODE_NONE)
  laneData.allyTowers = bot:GetNearbyTowers(MAX_SEARCH_RADIUS, false)
  laneData.enemyTowers = bot:GetNearbyTowers(MAX_SEARCH_RADIUS, true)
  return laneData
end

function FrontLineLocation(bot)
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

function LaneLocationScore(bot, location, laneData)
  local lowEnemyCreepsInRange = #Filter(laneData.enemyCreeps, function(creep) 
    return GetUnitToLocationDistance(creep, location) < ATTACK_CREEP_RANGE and creep:GetHealth() < LOW_CREEP_HP_MAX
  end)
  local enemyCreepsClose = #Filter(laneData.enemyCreeps, function(creep) 
    return GetUnitToLocationDistance(creep, location) < CREEP_CLOSE_RANGE
  end)
  local enemyCreepsInRange = #Filter(laneData.enemyCreeps, function(creep) 
    return GetUnitToLocationDistance(creep, location) < ATTACK_CREEP_RANGE
  end)
  local allyCreepsClose = #Filter(laneData.allyCreeps, function(creep) 
    return GetUnitToLocationDistance(creep, location) < CREEP_CLOSE_RANGE
  end)
  local enemyTowersInRange = #Filter(laneData.enemyTowers, function(tower) 
    return GetUnitToLocationDistance(tower, location) < TOWER_SAFETY_DISTANCE
  end)
  local enemyHeroesInRange = #Filter(laneData.enemyHeroes, function(hero) 
    return GetUnitToLocationDistance(hero, location) < ATTACK_CREEP_RANGE
  end)

  local score = lowEnemyCreepsInRange * LOW_ENEMY_CREEP_IN_RANGE_SCORE
  score = score + enemyCreepsClose * ENEMY_CREEP_CLOSE_SCORE
  score = score + enemyCreepsInRange * ENEMY_CREEP_IN_RANGE_SCORE
  score = score + allyCreepsClose * ALLIED_CREEP_CLOSE_SCORE
  score = score + enemyTowersInRange * IN_RANGE_OF_ENEMY_TOWER_SCORE
  score = score + enemyHeroesInRange * -2
  return score
end

function Think()
  
  function f()
    local bot = GetBot()
    local laneData = GetLaneData(bot)
    if not bot:IsUsingAbility() then
      -- Look for an enemy creep to attack
      local enemyCreeps = bot:GetNearbyCreeps(700, true)
      local attackTarget = nil
      for _,creep in ipairs(enemyCreeps) do
        if creep:GetHealth() <= bot:GetEstimatedDamageToTarget(true, creep, CREEP_ATTACK_DURATION, DAMAGE_TYPE_PHYSICAL) then
           attackTarget = creep
        end
      end
      
      -- Look for an enemy hero to harass
      if not attackTarget then
        local enemyHeroes = bot:GetNearbyHeroes(600, true, BOT_MODE_NONE)
        for _,hero in ipairs(enemyHeroes) do
          local enemyCreepsInRange = #(bot:GetNearbyCreeps(500, true))
          if enemyCreepsInRange <= 1 then
            attackTarget = hero
          end
        end
      end
      
      -- Look for an allied creep to deny
      if not attackTarget then
        local alliedCreeps = bot:GetNearbyCreeps(700, false)
        for _,creep in ipairs(alliedCreeps) do
        if creep:GetHealth() < math.min(creep:GetMaxHealth() / 2, bot:GetEstimatedDamageToTarget(true, creep, CREEP_ATTACK_DURATION, DAMAGE_TYPE_PHYSICAL)) then
           attackTarget = creep
        end
      end
      end
      if attackTarget then
        bot:Action_AttackUnit(attackTarget, false)
      else
        local frontLineLocation = FrontLineLocation(bot)
        frontLineLocation[1] = frontLineLocation[1] + RandomFloat(0, LOCATION_NOISE)
        frontLineLocation[2] = frontLineLocation[2] + RandomFloat(0, LOCATION_NOISE)
        local bestLocation = frontLineLocation
        for r = 0.2, 1 ,0.2 do
          for a = 0, 2*math.pi, 2*math.pi / 12 do
            local x = math.cos(a) * r * LANE_RADIUS
            local y = math.sin(a) * r * LANE_RADIUS
            local location = Vector(frontLineLocation[1] + x, frontLineLocation[2] + y, frontLineLocation[3])
            if IsLocationPassable(location) and LaneLocationScore(bot, location, laneData) > LaneLocationScore(bot, bestLocation, laneData) then
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