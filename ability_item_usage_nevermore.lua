
----------------------------------------------------------------------------------------------------

require( GetScriptDirectory().."/ability_item_usage_generic" )
require( GetScriptDirectory().."/util" )

local RAZE_HIT_HERO_SCORE = 1
local RAZE_KILL_CREEP_SCORE = 1
local RAZE_FULL_MANA_SCORE = 1

local RAZE_SCORE_THRESHOLD = 2

local activeAbilityName = nil
local lastHealingSalveTime = -100

function ItemUsageThink()
  ability_item_usage_generic.ItemUsageThink()
end

function razeScore(bot, raze)
  if not raze:IsFullyCastable() then return 0 end
  local angle = bot:GetFacing() / 180 * math.pi
  local castRange = raze:GetCastRange()
  local castPoint = raze:GetCastPoint()
  local damage = raze:GetAbilityDamage()
  local aoe = 250
  local location = bot:GetLocation()
  location[1] = location[1] + math.cos(angle)*castRange
  location[2] = location[2] + math.sin(angle)*castRange
  local creepsHit = 0
  local creeps = bot:GetNearbyCreeps(castRange + aoe, true)
  for i,creep in ipairs(creeps) do
    if creep:GetHealth() <= damage and GetUnitToLocationDistance(creep, location) < aoe then
      creepsHit = creepsHit + 1
    end
  end
  local heroesHit = 0
  local heroes = bot:GetNearbyHeroes(castRange + aoe, true, BOT_MODE_NONE)
  for i,hero in ipairs(heroes) do
    if GetUnitToLocationDistance(hero, location) < aoe and not hero:IsMagicImmune() and not hero:IsInvulnerable() then
      heroesHit = heroesHit + 1
    end
  end
  local score = creepsHit*RAZE_KILL_CREEP_SCORE + heroesHit*RAZE_HIT_HERO_SCORE
  if bot:GetMana() == bot:GetMaxMana() then
    score = score + RAZE_FULL_MANA_SCORE
  end
  return score
end

function AbilityUsageThink()
  
  local function f()
    local bot = GetBot()
    if bot:IsUsingAbility() then
      if activeAbilityName then
        local ability = bot:GetAbilityByName(activeAbilityName)
        if razeScore(bot, ability) < RAZE_SCORE_THRESHOLD then
          bot:Action_ClearActions(true)
        end
      end
    else
      local raze1 = bot:GetAbilityByName("nevermore_shadowraze1")
      local raze2 = bot:GetAbilityByName("nevermore_shadowraze2")
      local raze3 = bot:GetAbilityByName("nevermore_shadowraze3")
      local razes = {raze1, raze2, raze3}
      local bestRaze = nil
      for i,raze in ipairs(razes) do
        local score = razeScore(bot, raze)
        if score >= RAZE_SCORE_THRESHOLD and (not bestRaze or score > razeScore(bot, bestRaze)) then
          bestRaze = raze
        end
      end
      if bestRaze then
        bot:Action_UseAbility(bestRaze)
        activeAbilityName = bestRaze:GetName()
      end
    end
  end
  
  local status, err = pcall(f)
  if not status then
    print(err)
  end
  
end

---------------------------------------------------------------------------------------------------