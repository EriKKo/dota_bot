

----------------------------------------------------------------------------------------------------

_G._savedEnv = getfenv()
module( "ability_item_usage_generic", package.seeall )

----------------------------------------------------------------------------------------------------

function AbilityUsageThink()

	--print( "Generic.AbilityUsageThink" );

end

----------------------------------------------------------------------------------------------------

local lastHealingSalveTime = -100 -- To prevent using multiple healing salves at once
local lastStick = -100 -- To prevent spamming stick/wand TODO Need a cleaner way
local itemFunctions = {}
itemFunctions["item_bottle"] = function(bot, item)
  if bot:TimeSinceDamagedByAnyHero() > 2 and bot:GetMaxMana() - bot:GetMana() >= 60 and bot:GetMaxHealth() - bot:GetHealth() >= 90 then
    bot:Action_UseAbility(item)
  end
end

itemFunctions["item_courier"] = function(bot, item)
  bot:Action_UseAbility(item)
end

itemFunctions["item_flask"] = function(bot, item)
  -- Should check if affected by healing salve buff
  if GameTime() - lastHealingSalveTime > 10 and (bot:TimeSinceDamagedByAnyHero() > 5 or bot:GetHealth() < 50) and bot:GetMaxHealth() - bot:GetHealth() >= 400 then
    lastHealingSalveTime = GameTime()
    bot:Action_UseAbilityOnEntity(item, bot)
  end
end

itemFunctions["item_faerie_fire"] = function(bot, item)
  if bot:GetHealth() <= 70 then
    bot:Action_UseAbility(item)
  end
end

itemFunctions["item_magic_stick"] = function(bot, item)
  if GameTime() - lastStick > 5 and bot:GetHealth() <= 200 then
    lastStick = GameTime()
    bot:Action_UseAbility(item)
  end
end

itemFunctions["item_magic_wand"] = itemFunctions["item_magic_stick"]

function ItemUsageThink()
  local function f()
    local bot = GetBot()
    for i = 0,5 do
      local item = bot:GetItemInSlot(i)
      if item and item:IsFullyCastable() and itemFunctions[item:GetName()] then
        itemFunctions[item:GetName()](bot, item)
      end
    end
  end  
  local status,err = pcall(f)
  if not status then
    print(err)
  end
end

----------------------------------------------------------------------------------------------------


for k,v in pairs( ability_item_usage_generic ) do	_G._savedEnv[k] = v end
