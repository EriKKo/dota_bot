
local pickForPlayers = true
local heroes = {
  [TEAM_RADIANT] = {
    "npc_dota_hero_nevermore",
    "npc_dota_hero_lion",
    "npc_dota_hero_sven",
    "npc_dota_hero_razor",
    "npc_dota_hero_windrunner"
  },
  [TEAM_DIRE] = {
    "npc_dota_hero_lina",
    "npc_dota_hero_earthshaker",
    "npc_dota_hero_nevermore",
    "npc_dota_hero_mirana",
    "npc_dota_hero_juggernaut"
  }
}

function Think()
  function f()
    for i,player in ipairs(GetTeamPlayers(GetTeam())) do
      if pickForPlayers or IsPlayerBot(player) then
        SelectHero(player, heroes[GetTeam()][i])
      end
    end
  end
  local status, err = pcall(f)
  if not status then
    print(err)
  end
end