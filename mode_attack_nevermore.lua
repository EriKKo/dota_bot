
function GetClosestEnemy(bot)
  local enemies = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE)
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
      bot:Action_AttackUnit(enemy, false)
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