
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

---------------------------------------------------------------------------------------------------