
namespace LiveMatch {
    LiveMatch Deserialize(Json::Value @value) {
        auto match = LiveMatch();
        match.uid = value["uid"];
        match.config = MatchConfiguration::Deserialize(value["config"]);
        match.phase = GamePhase(int(value["phase"]));
        match.startTime = Time::Now - (Time::Stamp - uint64(value["started"])) * 1000;
        match.canReroll = bool(value["can_reroll"]);

        @match.teams = {};
        @match.players = {};
        for (uint i = 0; i < value["teams"].Length; i++) {
            Json::Value @t = value["teams"][i];
            Json::Value @base = t["base"];
            Team team = Team::Deserialize(base);
            match.teams.InsertLast(team);

            for (uint j = 0; j < t["members"].Length; j++) {
                auto playerJson = t["members"][j];
                Player player(PlayerProfile::Deserialize(playerJson), team);
                player.holdingPowerup = Powerup(int(playerJson["holding_powerup"]));

                match.players.InsertLast(player);
            }
        }

        @match.tiles = {};
        for (uint i = 0; i < value["cells"].Length; i++) {
            auto cell_json = value["cells"][i];
            GameMap map = GameMap::Deserialize(cell_json["map"]);
            GameTile cell = GameTile(map);
            for (uint j = 0; j < cell_json["claims"].Length; j++) {
                cell.attemptRanking.InsertLast(
                    MapClaim::Deserialize(cell_json["claims"][j], match));
            }
            cell.specialState = TileItemState(int(cell_json["state"]));
            if (cell_json["state_player"].GetType() != Json::Type::Null)
                cell.statePlayerTarget = PlayerRef::Deserialize(cell_json["state_player"]);
            if (cell_json.HasKey("state_deadline") && int(cell_json["state_deadline"]) != 0)
                cell.stateTimeDeadline = Time::Now + (int(cell_json["state_deadline"]) - Time::Stamp) * 1000;
            if (cell_json["claimant"].GetType() != Json::Type::Null)
                cell.claimant = match.GetTeamWithId(int(cell_json["claimant"]));
            match.tiles.InsertLast(cell);
        }
        return match;
    }
}
