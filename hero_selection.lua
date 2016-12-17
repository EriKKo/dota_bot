

----------------------------------------------------------------------------------------------------

function Think()

  function f()
    
    if GetGameMode() == GAMEMODE_1V1MID then
      if GetTeam() == TEAM_RADIANT then
        SelectHero(0, "npc_dota_hero_nevermore")
      elseif GetTeam() == TEAM_DIRE then       
        SelectHero(5, "npc_dota_hero_nevermore")
      end
    else
      if ( GetTeam() == TEAM_RADIANT )
      then
        print( "selecting radiant" );
        SelectHero( 1, "npc_dota_hero_nevermore" );
        SelectHero( 2, "npc_dota_hero_axe" );
        SelectHero( 3, "npc_dota_hero_bane" );
        SelectHero( 4, "npc_dota_hero_razor" );
        SelectHero( 5, "npc_dota_hero_crystal_maiden" );
      elseif ( GetTeam() == TEAM_DIRE )
      then
        print( "selecting dire" );
        SelectHero( 6, "npc_dota_hero_lina" );
        SelectHero( 7, "npc_dota_hero_earthshaker" );
        SelectHero( 8, "npc_dota_hero_nevermore" );
        SelectHero( 9, "npc_dota_hero_mirana" );
        SelectHero( 10, "npc_dota_hero_juggernaut" );
      end
    end
  end
  
  local status, err = pcall(f)
  if not status then
    print(err)
  end

end

----------------------------------------------------------------------------------------------------
