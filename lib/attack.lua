local geometry = require(GetScriptDirectory() .. "/lib/geometry")

local ATTACK_POINT_MARGIN = 0.0
local attackData = {}

local function GetAttackData(bot)
  local data = attackData[bot]
  if not data then
    data = {
      attackStartTime = 0,
      attackReadyTime = 0
    }
    attackData[bot] = data
  end
  return data
end

local function Attack(bot, target)
  local data = GetAttackData(bot)
  local actionType = bot:GetCurrentActionType()
  if GameTime() >= data.attackReadyTime then
    -- Can attack
    if actionType ~= BOT_ACTION_TYPE_ATTACK or bot:GetAttackTarget() ~= target or data.attackReadyTime > data.attackStartTime then
      -- Start new attack
      if GetUnitToUnitDistance(bot, target) < bot:GetAttackRange() + 50 then
        bot:Action_AttackUnit(target, true)
        data.attackStartTime = GameTime()
      else
        bot:Action_MoveToLocation(target:GetLocation())
      end
    else
      -- Continue attack
      local animationPoint = GameTime() - data.attackStartTime
      if animationPoint >= bot:GetAttackPoint() / bot:GetAttackSpeed() + ATTACK_POINT_MARGIN then
        data.attackReadyTime = data.attackStartTime + bot:GetSecondsPerAttack() + ATTACK_POINT_MARGIN
      end
    end
  else
    -- Can't attack, move instead
    bot:Action_MoveToLocation(geometry.MoveAlongLine(target:GetLocation(), bot:GetLocation(), bot:GetAttackRange()))
    --[[
    if GetUnitToUnitDistance(bot, target) >= bot:GetAttackRange() + 50 then
      bot:Action_MoveToLocation(target:GetLocation())
    end
    ]]--
  end
end

local function IsAttacking(bot)
  local data = GetAttackData(bot)
  return bot:GetCurrentActionType() == BOT_ACTION_TYPE_ATTACK and data.attackStartTime >= data.attackReadyTime
end

local function CanAttack(bot)
  local data = GetAttackData(bot)
  return GameTime() >= data.attackReadyTime
end

return {
  Attack = Attack,
  IsAttacking = IsAttacking,
  CanAttack = CanAttack
}