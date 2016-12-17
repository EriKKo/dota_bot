

local tableItemsToBuy = { 
				"item_flask",
				"item_flask",
				"item_circlet",
        "item_branches",
				"item_branches",
        "item_faerie_fire",
				"item_slippers",
				"item_recipe_wraith_band",
				"item_circlet",
				"item_magic_stick",
				"item_circlet",
        "item_slippers",
				"item_recipe_wraith_band",
        "item_sobi_mask",
        "item_ring_of_protection",
				"item_boots",
        "item_belt_of_strength",
        "item_gloves"
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
		npcBot:Action_PurchaseItem( sNextItem );
		table.remove( tableItemsToBuy, 1 );
	end

end

----------------------------------------------------------------------------------------------------
