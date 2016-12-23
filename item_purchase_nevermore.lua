

local tableItemsToBuy = {
				"item_flask",
				"item_flask",
				"item_circlet",
        "item_circlet",
        "item_faerie_fire",
				"item_slippers",
				"item_recipe_wraith_band",
        "item_slippers",
				"item_recipe_wraith_band",
        "item_infused_raindrop",
        "item_boots",
        "item_sobi_mask",
        "item_ring_of_protection",
        "item_belt_of_strength",
        "item_gloves",
        "item_blade_of_alacrity",
        "item_boots_of_elves",
        "item_recipe_yasha",
        "item_ogre_axe",
        "item_belt_of_strength",
        "item_recipe_sange"
			};


----------------------------------------------------------------------------------------------------

function ItemPurchaseThink()

	if ( #tableItemsToBuy == 0 )
	then
		npcBot:SetNextItemPurchaseValue( 0 );
		return;
	end

	local sNextItem = tableItemsToBuy[1];
	local npcBot = GetBot();

	npcBot:SetNextItemPurchaseValue( GetItemCost( sNextItem ) );

	if ( npcBot:GetGold() >= GetItemCost( sNextItem ) )
	then
    npcBot:Action_Chat("Bought " .. sNextItem, true)
		npcBot:Action_PurchaseItem( sNextItem );
		table.remove( tableItemsToBuy, 1 );
	end

end

----------------------------------------------------------------------------------------------------
