local Deque = require(GetScriptDirectory() .. "/lib/deque").Deque
local GeometryUtil = require(GetScriptDirectory() .. "/lib/geometry_util")
local AttackUtil = require(GetScriptDirectory() .. "/lib/attack_util")
local ItemUtil = require(GetScriptDirectory() .. "/lib/item_util")

local LOCATION_NOISE = 150
local MAX_SEARCH_RADIUS = 1600
local LANE_RADIUS = 800
local EXPERIENCE_RADIUS = 1200
local CREEP_CLOSE_RANGE = 200
local INFINITY = 1000000
local AGGRO_RANGE = 500

local MANA_POOL_VALUE = 0.5
local LASTHIT_DAMAGE_MARGIN = 15
local LASTHIT_SCORE = 0.1
local DENY_SCORE = 0.05
local ENEMY_CREEP_IN_EXP_RANGE_SCORE = 0.01
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
local creepDamagePrediction = {}
local lastMoveTarget = nil

function CalculateLaneData(bot)
  laneData.allyCreeps = bot:GetNearbyCreeps(MAX_SEARCH_RADIUS, false)
  laneData.enemyCreeps = bot:GetNearbyCreeps(MAX_SEARCH_RADIUS, true)
  laneData.allyHeroes = bot:GetNearbyHeroes(MAX_SEARCH_RADIUS, false, BOT_MODE_NONE)
  laneData.enemyHeroes = bot:GetNearbyHeroes(MAX_SEARCH_RADIUS, true, BOT_MODE_NONE)
  laneData.allyTowers = bot:GetNearbyTowers(MAX_SEARCH_RADIUS, false)
  laneData.enemyTowers = bot:GetNearbyTowers(MAX_SEARCH_RADIUS, true)
  
  local gameTime = GameTime()
  local newCreepDamagePrediction = {}
  -- TODO ignore hero-inflicted damage / damage outside possible ranges
  function update(creeps)
    for _,creep in ipairs(creeps) do
      local newHealth = creep:GetHealth()
      local oldHealth = creepHealth[creep] or newHealth
      creepHealth[creep] = newHealth
      local damagePrediction = creepDamagePrediction[creep] or Deque()
      if newHealth < oldHealth then
        damagePrediction.AddLast({damage = oldHealth - newHealth, time = gameTime + 1})
      end
      while damagePrediction.PeekFirst() and gameTime + 0.05 > damagePrediction.PeekFirst().time do
        damagePrediction.PollFirst()
      end
      newCreepDamagePrediction[creep] = damagePrediction
    end
  end
  update(laneData.allyCreeps)
  update(laneData.enemyCreeps)
  creepDamagePrediction = newCreepDamagePrediction
  
  aggroData = {}
  distanceToClosestTarget = {}
  function CalculateAggro(sourceGroup, targetGroups)
    for _,source in ipairs(sourceGroup) do
      local closestTarget = nil
      distanceToClosestTarget[source] = INFINITY
      for _,targetGroup in ipairs(targetGroups) do
        for _,target in ipairs(targetGroup) do
          local dist = GetUnitToUnitDistance(source, target)
          if dist < math.min(AttackUtil.GetThreatRange(source, target), distanceToClosestTarget[source]) then
            closestTarget = target
            distanceToClosestTarget[source] = dist
          end
        end
      end
      if closestTarget then
        aggroData[closestTarget] = (aggroData[closestTarget] or 0) + AttackUtil.GetDPS(source, closestTarget)
      end
    end
  end
  CalculateAggro(laneData.allyCreeps, {laneData.enemyCreeps, laneData.enemyHeroes})
  CalculateAggro(laneData.allyTowers, {laneData.enemyCreeps, laneData.enemyHeroes})
  CalculateAggro(laneData.enemyCreeps, {laneData.allyCreeps, {bot}})
  CalculateAggro(laneData.enemyTowers, {laneData.allyCreeps, {bot}})
end

function GetFrontLineLocation(bot)
  --
  local ownFountain = GeometryUtil.GetFountainLocation()
  local enemyFountain = GeometryUtil.GetFountainLocation(true)
  local minLocation = ownFountain
  local maxLocation = enemyFountain
  -- Use the front tower as front line if creeps are not there yet
  for _,allyTower in ipairs(laneData.allyTowers) do
    local towerSafetyLocation = allyTower:GetLocation()
    if #(towerSafetyLocation - ownFountain) > #(minLocation - ownFountain) then
      minLocation = towerSafetyLocation
    end
  end
  -- Make sure we don't towerdive
  for _,enemyTower in ipairs(laneData.enemyTowers) do
    local beforeTowerLocation = GeometryUtil.GetLocationAlongLine(enemyTower:GetLocation(), ownFountain, AttackUtil.GetThreatRange(enemyTower, bot))
    if #(beforeTowerLocation - ownFountain) < #(maxLocation - ownFountain) then
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
    frontLineLocation = GetLaneFrontLocation(GetTeam(), bot:GetAssignedLane(), 0)
  end
  -- Check position of enemy heroes
  for _,enemyHero in ipairs(laneData.enemyHeroes) do
    if GetUnitToLocationDistance(enemyHero, ownFountain) < #(frontLineLocation - ownFountain) then
      frontLineLocation = enemyHero:GetLocation()
    end
  end
  if #(frontLineLocation - ownFountain) < #(minLocation - ownFountain) then
    return minLocation
  elseif #(frontLineLocation - ownFountain) > #(maxLocation - ownFountain) then
    return maxLocation
  else
    return frontLineLocation
  end
end

function GetLaneLocationScore(bot, newLocation)
  newLocation = newLocation or bot:GetLocation()
  local score = -AttackUtil.GetThreatFromSources(bot, newLocation, {laneData.enemyCreeps, laneData.enemyTowers})
  -- Get threat from heroes and take into account defending creeps
  for _,enemyHero in ipairs(laneData.enemyHeroes) do
    local enemyLocation = enemyHero:GetLocation()
    if #(enemyLocation - newLocation) > AttackUtil.GetAttackRange(enemyHero, bot) then
      enemyLocation = GeometryUtil.GetLocationAlongLine(newLocation, enemyLocation, AttackUtil.GetAttackRange(enemyHero, bot))
    end
    local enemyThreat = AttackUtil.GetThreat(enemyHero, bot, enemyLocation, newLocation)
    enemyThreat = enemyThreat - AttackUtil.GetThreatFromSources(enemyHero, enemyLocation, {laneData.allyCreeps, laneData.allyTowers})
    enemyThreat = math.max(0, enemyThreat)
    score = score - enemyThreat
  end
  local creepKillScore = 0
  -- Add score belonging to the lane location
  for _,enemyCreep in ipairs(laneData.enemyCreeps) do
    local dist = GetUnitToLocationDistance(enemyCreep, newLocation)
    creepKillScore = creepKillScore + LASTHIT_SCORE * AttackUtil.GetThreat(bot, enemyCreep, newLocation)
    if dist < EXPERIENCE_RADIUS then
      score = score + ENEMY_CREEP_IN_EXP_RANGE_SCORE
    end
    if dist < CREEP_CLOSE_RANGE then
      score = score + CREEP_CLOSE_SCORE
    end
  end
  for _,allyCreep in ipairs(laneData.allyCreeps) do
    creepKillScore = math.max(creepKillScore, DENY_SCORE * AttackUtil.GetThreat(bot, allyCreep, newLocation))
    if GetUnitToLocationDistance(allyCreep, newLocation) < CREEP_CLOSE_RANGE then
      score = score + CREEP_CLOSE_SCORE
    end
  end
  score = score + creepKillScore
  return score
end

function GetMoveScore(bot, newLocation)
  local duration = GetUnitToLocationDistance(bot, newLocation) / bot:GetCurrentMovementSpeed()
  return (GetLaneLocationScore(bot, newLocation) - GetLaneLocationScore(bot)) --/ (duration + 1)
end

function GetMoveAction(bot)
  local frontLineLocation = GetFrontLineLocation(bot)
  local bestMove = frontLineLocation
  local moveScore = GetMoveScore(bot, frontLineLocation)
  function TestMove(move)
    if not bestMove or GetMoveScore(bot, move) > moveScore then
      bestMove = move
      moveScore = GetMoveScore(bot, move)
    end
  end
  
  if lastMoveTarget and #(lastMoveTarget - bestMove) <= LANE_RADIUS then
    TestMove(lastMoveTarget)
  end
  local LINES = 3
  local angleOffset = RandomFloat(0, 2*math.pi / LINES)
  for r = 0.2, 1 ,0.2 do
    for i = 1, LINES do
      local angle = angleOffset + 2*math.pi / LINES * (i-1)
      local x = math.cos(angle) * r * LANE_RADIUS + RandomFloat(0, LOCATION_NOISE)
      local y = math.sin(angle) * r * LANE_RADIUS + RandomFloat(0, LOCATION_NOISE)
      local location = Vector(frontLineLocation[1] + x, frontLineLocation[2] + y, frontLineLocation[3])
      if IsLocationPassable(location) then
        TestMove(location)
      end
    end
  end
  lastMoveTarget = bestMove
  local moveAction = function()
    bot:Action_MoveToLocation(bestMove)
  end
  return moveAction, moveScore
end

function GetHarassAction(bot)
  local harassTarget = nil
  local harassScore = -INFINITY
  local attackCooldown = AttackUtil.GetAttackCooldown(bot)
  for _,enemyHero in ipairs(laneData.enemyHeroes) do
    local harassLocation = bot:GetLocation()
    local timeToCatch = 0
    if GetUnitToUnitDistance(bot, enemyHero) > AttackUtil.GetAttackRange(bot, enemyHero) or attackCooldown > 0 then
      local PREDICTION_TIME = 1
      local walkDistance = math.max(0, GetUnitToUnitDistance(bot, enemyHero) - AttackUtil.GetAttackRange(bot, enemyHero))
      local newEnemyLocation = AttackUtil.GetProbableLocation(enemyHero, PREDICTION_TIME)
      local newWalkDistance = GetUnitToLocationDistance(bot, newEnemyLocation) - AttackUtil.GetAttackRange(bot, enemyHero) - PREDICTION_TIME * bot:GetCurrentMovementSpeed()
      if walkDistance > 0 then
        if newWalkDistance < walkDistance then
          timeToCatch = PREDICTION_TIME * (1 + newWalkDistance / (walkDistance - newWalkDistance))
        else
          timeToCatch = INFINITY
        end
      end
      harassLocation = GeometryUtil.GetLocationAlongLine(newEnemyLocation, bot:GetLocation(), AttackUtil.GetAttackRange(bot, enemyHero))
    end
    local incomingAggro = 0
    -- Calculate aggro if we have not already aggro'd the creeps
    if not AttackUtil.IsAttacking(bot) then
      for _,enemies in ipairs({laneData.enemyCreeps, laneData.enemyTowers}) do
        for _,enemy in ipairs(enemies) do
          if GetUnitToLocationDistance(enemy, harassLocation) < math.max(AGGRO_RANGE, AttackUtil.GetAttackRange(enemy, bot)) then
            incomingAggro = incomingAggro + AttackUtil.GetThreat(enemy, bot, nil, harassLocation)
          end
        end
      end
    end
    local outgoingAggro = 0
    -- TODO Get harass location of enemy
    for _,allies in ipairs({laneData.allyCreeps, laneData.allyTowers}) do
      for _,ally in ipairs(allies) do
        if GetUnitToUnitDistance(ally, enemyHero) < AGGRO_RANGE then
          outgoingAggro = outgoingAggro + AttackUtil.GetThreat(ally, enemyHero)
        end
      end
    end
    local outgoingThreat = AttackUtil.GetThreat(bot, enemyHero, harassLocation)
    local incomingThreat = AttackUtil.GetThreat(enemyHero, bot, nil, harassLocation)
    local chaseScore = outgoingThreat - incomingAggro * (1 + timeToCatch)
    local fightScore = outgoingThreat - incomingAggro + outgoingAggro - incomingThreat
    score = math.min(chaseScore, fightScore) + GetMoveScore(bot, harassLocation)
    if score > harassScore then
      harassTarget = enemyHero
      harassScore = score
    end
  end
  local harassAction = function()
    AttackUtil.Attack(bot, harassTarget)
  end
  return harassAction, harassScore
end

function GetLastHitAction(bot)
  local target = nil
  local score = -INFINITY
  function FindTarget(creeps, enemy)
    for _,creep in ipairs(creeps) do
      local dist = GetUnitToUnitDistance(creep, bot)
      if enemy or creep:GetHealth() < creep:GetMaxHealth() / 2 then
        local attackHitTime = GameTime() +  bot:GetAttackPoint() / bot:GetAttackSpeed() + math.min(dist, AttackUtil.GetAttackRange(bot, creep)) / 1200
        local attackLocation = bot:GetLocation()
        local timeBeforeAttack = AttackUtil.GetAttackCooldown(bot)
        if dist > AttackUtil.GetAttackRange(bot, creep) then
          timeBeforeAttack = math.max(timeBeforeAttack, (dist - AttackUtil.GetAttackRange(bot, creep)) / bot:GetCurrentMovementSpeed())
          attackLocation = GeometryUtil.GetLocationAlongLine(creep:GetLocation(), bot:GetLocation(), AttackUtil.GetAttackRange(bot, creep))
        end
        attackHitTime = attackHitTime + timeBeforeAttack
        attackHitTime = attackHitTime + GeometryUtil.GetTurnTime(bot, creep)
        local damage = 0
        local damagePrediction = creepDamagePrediction[creep]
        for i = damagePrediction.first,damagePrediction.last do
          if damagePrediction[i].time > attackHitTime then
            break
          end
          damage = damage + damagePrediction[i].damage
        end
        damage = damage + creep:GetActualDamage(bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
        local damageNeeded = creep:GetHealth()
        if enemy then
          damageNeeded = damageNeeded + LASTHIT_DAMAGE_MARGIN
        end
        if damage >= damageNeeded then
          local lastHitScore = (enemy and LASTHIT_SCORE or DENY_SCORE) + GetMoveScore(bot, attackLocation)
          if lastHitScore > score then
            score = lastHitScore
            target = creep
          end
        end
      end
    end
  end
  FindTarget(laneData.enemyCreeps, true)
  FindTarget(laneData.allyCreeps, false)
  local lasthitAction = function()
    AttackUtil.Attack(bot, target)
  end
  return lasthitAction, score
end

function GetTangoTree(bot)
  local trees = bot:GetNearbyTrees(MAX_SEARCH_RADIUS)
  local ownFountain = GeometryUtil.GetFountainLocation()
  local maxTreeFountainDist = #(GetFrontLineLocation(bot) - ownFountain)
  for _,tree in ipairs(trees) do
    local treeLocation = GetTreeLocation(tree)
    if #(treeLocation - ownFountain) < maxTreeFountainDist then
      return tree
    end
  end
end

function GetRegenAction(bot)
  local score = -INFINITY
  local action = nil
  local scoreLossPerSecond = 4*LASTHIT_SCORE / 30
  -- TODO Check how much heal remains from active modifiers
  local missingHealth = bot:GetMaxHealth() - bot:GetHealth()
  local currentTangoHeal = math.min(missingHealth, bot:HasModifier("modifier_tango_heal") and 115 or 0)
  local currentSalveHeal = math.min(missingHealth, bot:HasModifier("modifier_flask_healing") and 400 or 0)
  local currentHeal = math.min(missingHealth, currentSalveHeal + currentTangoHeal)
  local missingMana = bot:GetMaxMana() - bot:GetMana()
  if missingHealth > 0 then
    -- Check tango usage
    if not bot:HasModifier("modifier_tango_heal") then
      local tango = ItemUtil.GetItem(bot, "item_tango")
      if tango then
        local tree = GetTangoTree(bot)
        if tree then
          local treeLocation = GetTreeLocation(tree)
          local moveDuration = 2 * GetUnitToLocationDistance(bot, treeLocation) / bot:GetCurrentMovementSpeed()
          local maxHeal = tango:GetSpecialValueInt("total_heal")
          local actualHeal = math.min(maxHeal, missingHealth - currentHeal)
          local wastedHeal = maxHeal - actualHeal
          local tangoScore = (actualHeal - wastedHeal) / bot:GetMaxHealth()
          tangoScore = tangoScore - moveDuration*scoreLossPerSecond
          tangoScore = tangoScore + GetMoveScore(bot, treeLocation)
          if tangoScore > score then
            score = tangoScore
            action = function()
              bot:Action_UseAbilityOnTree(tango, tree)
            end
          end
        end
      end
    end
    -- Check healing salve
    local healLocation = bot:GetLocation()
    for _,enemyHero in ipairs(laneData.enemyHeroes) do
      if GetUnitToUnitDistance(bot, enemyHero) < AttackUtil.GetThreatRange(enemyHero, bot) then
        healLocation = GeometryUtil.GetLocationAlongLine(enemyHero:GetLocation(), GeometryUtil.GetFountainLocation(), AttackUtil.GetThreatRange(enemyHero, bot) * 1.5)
      end
    end
    if bot:HasModifier("modifier_flask_healing") and #(healLocation - bot:GetLocation()) > 0 then
      local salveScore = (missingHealth - currentTangoHeal) / bot:GetMaxHealth()
      salveScore = salveScore + GetMoveScore(bot, healLocation)
      if salveScore > score then
        score = salveScore
        action = function()
          bot:Action_MoveToLocation(healLocation)
        end
      end
    else
      local salve = ItemUtil.GetItem(bot, "item_flask")
      if salve then
        local maxHeal = salve:GetSpecialValueInt("total_health")
        local actualHeal = math.min(maxHeal, missingHealth - currentHeal)
        local wastedHeal = maxHeal - actualHeal
        local healDuration = salve:GetSpecialValueInt("buff_duration") * actualHeal / maxHeal
        local moveDuration = 2 * GetUnitToLocationDistance(bot, healLocation) / bot:GetCurrentMovementSpeed() + healDuration
        local salveScore = (actualHeal - wastedHeal) / bot:GetMaxHealth()
        salveScore = salveScore - moveDuration*scoreLossPerSecond
        salveScore = salveScore + GetMoveScore(bot, healLocation)
        if salveScore > score then
          score = salveScore
          if GetUnitToLocationDistance(bot, healLocation) == 0 then
            action = function()
              bot:Action_UseAbilityOnEntity(salve, bot)
            end
          else
            action = function()
              bot:Action_MoveToLocation(healLocation)
            end
          end
        end
      end
    end
  end
  
  if missingHealth > 0 or missingMana > 0 then
    -- Check fountain trip
    local fountainLocation = GeometryUtil.GetFountainLocation()
    local fountainTime = 2 * GetUnitToLocationDistance(bot, fountainLocation) / bot:GetCurrentMovementSpeed()
    local fountainScore = (missingHealth - currentHeal) / bot:GetMaxHealth() + MANA_POOL_VALUE * missingMana / bot:GetMaxMana() - fountainTime*scoreLossPerSecond + GetMoveScore(bot, fountainLocation)
    if fountainScore > score then
      score = fountainScore
      action = function()
        bot:Action_MoveToLocation(fountainLocation)
      end
    end
  end
  
  return action, score
end

local activeRazeName = nil
local activeRazeStartTime = nil

function GetRazeAction(bot)
  local score = -INFINITY
  local action = nil
  local botLocation = bot:GetLocation()
  
  function CheckRaze(razeName)
    local raze = bot:GetAbilityByName(razeName)
    if raze:IsFullyCastable() then
      local currentAngle = bot:GetFacing() / 180 * math.pi
      local radius = raze:GetSpecialValueInt("shadowraze_radius")
      local castRange = raze:GetCastRange()
      local castPoint = raze:GetCastPoint()
      if activeRazeName == razeName then
        -- We have already started casting raze
        castPoint = castPoint - (GameTime() - activeRazeStartTime)
        if castPoint < 0 then
          return
        end
      end
      local damage = raze:GetAbilityDamage()
      local damageType = raze:GetDamageType()
      local targets = {}
      for _,enemies in ipairs({laneData.enemyCreeps, laneData.enemyHeroes}) do
        for _,enemy in ipairs(enemies) do
          local enemyLocation = AttackUtil.GetProbableLocation(enemy, castPoint)
          local dist = #(enemyLocation - botLocation)
          local hitRadius = radius + enemy:GetBoundingRadius()
          if math.abs(dist - castRange) <= hitRadius and (enemy:IsHero() or enemy:GetHealth() <= enemy:GetActualDamage(damage, damageType)) then
            local angle = GeometryUtil.GetAngle(botLocation, enemyLocation)
            local angleDiff = 0.95*math.acos((dist*dist + castRange*castRange - hitRadius*hitRadius) / (2*dist*castRange))
            table.insert(targets, angle)
            table.insert(targets, angle + angleDiff)
            table.insert(targets, angle - angleDiff)
          end
        end
      end
      
      function GetAngleScore(angle)
        local location = bot:GetLocation()
        location[1] = location[1] + math.cos(angle)*castRange
        location[2] = location[2] + math.sin(angle)*castRange
        local razeScore = 0
        for _,enemies in ipairs({laneData.enemyCreeps, laneData.enemyHeroes}) do
          for _,enemy in ipairs(enemies) do
            local enemyLocation = AttackUtil.GetProbableLocation(enemy, castPoint)
            local hitRadius = radius + enemy:GetBoundingRadius()
            local actualDamage = math.min(enemy:GetHealth(), enemy:GetActualDamage(damage, damageType))
            if #(enemyLocation - location) <= hitRadius and not enemy:IsMagicImmune() and not enemy:IsInvulnerable() then
              if enemy:IsHero() then
                razeScore = razeScore + actualDamage / enemy:GetHealth()
              elseif actualDamage >= enemy:GetHealth() then
                razeScore = razeScore + LASTHIT_SCORE
              end
            end
          end
        end
        razeScore = razeScore - MANA_POOL_VALUE * raze:GetManaCost() / bot:GetMana()
        return razeScore
      end
      
      local currentScore = GetAngleScore(currentAngle)
      if currentScore > score then
        score = currentScore
        action = function()
          if not activeRazeName then
            activeRazeName = razeName
            activeRazeStartTime = GameTime()
            bot:Action_UseAbility(raze)
          end
        end
      end
      if activeRazeName ~= razeName then
        for _,angle in ipairs(targets) do
          local razeScore = GetAngleScore(angle)
          if razeScore > score then
            score = razeScore
            action = function()
              local location = botLocation
              location[1] = location[1] + math.cos(angle)*castRange
              location[2] = location[2] + math.sin(angle)*castRange
              AttackUtil.FaceLocation(bot, location)
            end
          end
        end
      end
    end
  end
  
  if activeRazeName then
    CheckRaze(activeRazeName)
  end
  if not action then
    activeRazeName = nil
    for _,razeName in ipairs({"nevermore_shadowraze1", "nevermore_shadowraze2", "nevermore_shadowraze3"}) do
      CheckRaze(razeName)
    end
  end
  return action, score
end

function Think()
  
  function f()
    local bot = GetBot()
    CalculateLaneData(bot)
    
    local actionType = bot:GetCurrentActionType()
    if bot:IsAlive() then
      local regenAction, regenScore = GetRegenAction(bot)
      local lasthitAction, lasthitScore = GetLastHitAction(bot)
      local moveAction, moveScore = GetMoveAction(bot)
      local harassAction, harassScore = GetHarassAction(bot)
      local razeAction, razeScore = GetRazeAction(bot)
      local bestScore = math.max(lasthitScore, math.max(moveScore, math.max(regenScore, math.max(razeScore, harassScore))))
      if bestScore > 0 then
        if regenScore > 0 then print("Regen", regenScore) end
        if lasthitScore > 0 then print("Lasthit", lasthitScore) end
        if moveScore > 0 then print("Move", moveScore) end
        if harassScore > 0 then print("Harass", harassScore) end
        if razeScore > 0 then print("Raze", razeScore) end
        print()
      end
      if razeScore == bestScore then
        razeAction()
      else
        if activeRazeName then
          activeRazeName = nil
          bot:Action_ClearActions(true)
        end
        if moveScore == bestScore then
          -- Move
          moveAction()
        elseif regenScore == bestScore then
          -- Go to regen
          regenAction()
        elseif harassScore == bestScore then
          -- Harass
          harassAction()
        elseif lasthitScore == bestScore then
          -- Lasthit
          lasthitAction()
        else
          print("Wat")
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