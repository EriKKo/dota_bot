
----------------------------------------------------------------------------------------------------

require( GetScriptDirectory().."/ability_item_usage_generic" )

local itemFunctionOverride = {}
--[[ TO USE WHEN API ALLOWS GETTING INDEX OF CREATED TREE
itemFunctionOverride["item_tango"] = function(bot, item)
  if not bot:HasModifier("modifier_tango_heal") and bot:GetMaxHealth() - bot:GetHealth() >= 115 then
    local tree = bot:GetNearbyTrees(item:GetCastRange())[1]
    if tree then
      bot:Action_UseAbilityOnTree(item, tree)
    else
      -- Try to use a branch for tree eating
      for i = 0,5 do
        local branches = bot:GetItemInSlot(i)
        if branches and branches:IsFullyCastable() and branches:GetName() == "item_branches" then
          bot:Action_UseAbilityOnLocation(branches, bot:GetLocation())
          break
        end
      end
    end
  end
end
]]--

function ItemUsageThink()
  ability_item_usage_generic.ItemUsageThink(itemFunctionOverride)
end

function AbilityUsageThink()

end

local abilities = {"nevermore_shadowraze1", "nevermore_shadowraze2", "nevermore_shadowraze3", "nevermore_necromastery", "nevermore_dark_lord", "nevermore_requiem", "special_bonus_movement_speed_15", "special_bonus_attack_speed_20", "special_bonus_spell_amplify_6", "special_bonus_hp_175", "special_bonus_evasion_15", "special_bonus_unique_nevermore_1", "special_bonus_attack_range_150", "special_bonus_unique_nevermore_2"}
local abilityLevelupOrder = {
  "nevermore_necromastery", 
  "nevermore_shadowraze1",
  "nevermore_shadowraze1",
  "nevermore_necromastery",
  "nevermore_shadowraze1",
  "nevermore_necromastery",
  "nevermore_shadowraze1",
  "nevermore_necromastery",
  "nevermore_requiem",
  "special_bonus_movement_speed_15",
  "nevermore_dark_lord",
  "nevermore_requiem",
  "nevermore_dark_lord",
  "nevermore_dark_lord",
  "special_bonus_hp_175",
  "nevermore_dark_lord",
  nil,
  "nevermore_requiem",
  nil,
  "special_bonus_unique_nevermore_1",
  nil,
  nil,
  nil,
  nil,
  "special_bonus_attack_range_150"
}

local function GetHeroLevel(bot)
  local respawnTable = {8, 10, 12, 14, 16, 26, 28, 30, 32, 34, 36, 46, 48, 50, 52, 54, 56, 66, 70, 74, 78,  82, 86, 90, 100};
  local nRespawnTime = bot:GetRespawnTime() + 1
  for k,v in pairs (respawnTable) do
    if v == nRespawnTime then
      return k
    end
  end
end

function AbilityLevelUpThink()
  function f()
    local bot = GetBot()
    local heroLevel = GetHeroLevel(bot)
    for i = heroLevel,1,-1 do
      local abilityName = abilityLevelupOrder[i]
      if abilityName and bot:GetAbilityByName(abilityName):CanAbilityBeUpgraded() then
        --print(GetTeam(), "Leveling", abilityName, bot:GetAbilityByName(abilityName):GetLevel())
        bot:Action_LevelAbility(abilityName)
        break
      end
    end
  end
  local status, err = pcall(f)
  if not status then
    print(err)
  end
end

---------------------------------------------------------------------------------------------------