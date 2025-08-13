
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
                auto player = t["members"][j];
                match.players.InsertLast(Player(PlayerProfile::Deserialize(player), team));
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
            match.tiles.InsertLast(cell);
        }
        return match;
    }
}
