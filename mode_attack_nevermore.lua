local AttackUtil = require(GetScriptDirectory() .. "/lib/attack_util")
local GeometryUtil = require(GetScriptDirectory() .. "/lib/geometry_util")

function GetClosestEnemy(bot)
  local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
  local closestEnemy = nil
  for _,enemy in pairs(enemies) do
    if not closestEnemy or GetUnitToUnitDistance(enemy, bot) < GetUnitToUnitDistance(closestEnemy, bot) then
      --print("Distance: "..GetUnitToUnitDistance(enemy, bot))
      closestEnemy = enemy
    end
  end
  return closestEnemy
end

function Think()
  
  function f()
    local bot = GetBot()
    local enemy = GetClosestEnemy(bot)
    if enemy then
      print(enemy:GetMovementDirectionStability())
      bot:Action_MoveToLocation(enemy:GetLocation() + enemy:GetExtrapolatedLocation(0.55) * enemy:GetMovementDirectionStability())
    else
      local shrine = GetShrine(GetTeam(), SHRINE_JUNGLE_1)
      print(shrine:GetUnitName())
      bot:Action_MoveToLocation(shrine:GetLocation())
    end
  end
  local status, err = pcall(f)
  if not status then
    print(err)
  end
end

function GetDesire()
  local res = 0
  function f()
    local bot = GetBot()
    local enemy = GetClosestEnemy(bot)
    if enemy then
      res = 1
    end
  end
  local status,err = pcall(f)
  if not status then
    print(err)
  end
  return 0
  --return res
end