

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
        SelectHero( 0, "npc_dota_hero_nevermore" );
        SelectHero( 1, "npc_dota_hero_medusa" );
        SelectHero( 2, "npc_dota_hero_mirana" );
        SelectHero( 3, "npc_dota_hero_razor" );
        SelectHero( 4, "npc_dota_hero_windrunner" );
      elseif ( GetTeam() == TEAM_DIRE )
      then
        print( "selecting dire" );
        SelectHero( 5, "npc_dota_hero_lina" );
        SelectHero( 6, "npc_dota_hero_earthshaker" );
        SelectHero( 7, "npc_dota_hero_nevermore" );
        SelectHero( 8, "npc_dota_hero_mirana" );
        SelectHero( 9, "npc_dota_hero_juggernaut" );
      end
    end
  end
  
  local status, err = pcall(f)
  if not status then
    print(err)
  end

end

----------------------------------------------------------------------------------------------------
