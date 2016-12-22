

----------------------------------------------------------------------------------------------------

_G._savedEnv = getfenv()
module( "ability_item_usage_generic", package.seeall )

----------------------------------------------------------------------------------------------------

function AbilityUsageThink()

	--print( "Generic.AbilityUsageThink" );

end

----------------------------------------------------------------------------------------------------

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

itemFunctions["item_tome_of_knowledge"] = function(bot, item)
  bot:Action_UseAbility(item)
end

itemFunctions["item_clarity"] = function(bot, item)
  if not bot:HasModifier("modifier_clarity_potion") and bot:TimeSinceDamagedByAnyHero() > 4 and bot:GetMaxMana() - bot:GetMana() >= 190 then
    bot:Action_UseAbilityOnEntity(item, bot)
  end
end


itemFunctions["item_flask"] = function(bot, item)
  if not bot:HasModifier("modifier_flask_healing") and (bot:TimeSinceDamagedByAnyHero() > 4 or bot:GetHealth() < 50) and bot:GetMaxHealth() - bot:GetHealth() >= 400 then
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

itemFunctions["item_tango"] = function(bot, item)
  if not bot:HasModifier("modifier_tango_heal") and bot:GetMaxHealth() - bot:GetHealth() >= 115 then
    local tree = bot:GetNearbyTrees(item:GetCastRange())[1]
    if tree then
      bot:Action_UseAbilityOnTree(item, tree)
    end
  end
end

itemFunctions["item_tango_single"] = itemFunctions["item_tango"]

function ItemUsageThink(itemFunctionOverride)
  itemFunctionOverride = itemFunctionOverride or {}
  local function f()
    local bot = GetBot()
    for i = 0,5 do
      local item = bot:GetItemInSlot(i)
      if item and item:IsFullyCastable() then
        if itemFunctionOverride[item:GetName()] then
          itemFunctionOverride[item:GetName()](bot, item)
        elseif itemFunctions[item:GetName()] then
          itemFunctions[item:GetName()](bot, item)
        end
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
