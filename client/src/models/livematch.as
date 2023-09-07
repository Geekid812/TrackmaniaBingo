
namespace LiveMatch {
    LiveMatch Deserialize(Json::Value@ value) {
        auto match = LiveMatch();
        match.uid = value["uid"];
        match.config = MatchConfiguration::Deserialize(value["config"]);
        match.phase = MatchPhase(int(value["phase"]));
        match.startTime = Time::Now - (Time::Stamp - uint64(value["started"])) * 1000;

        @match.teams = {};
        @match.players = {};
        for (uint i = 0; i < value["teams"].Length; i++) {
            Json::Value@ t = value["teams"][i];
            Json::Value@ base = t["base"];
            Team team = Team(
                base["id"], 
                base["name"],
                vec3(base["color"][0] / 255., base["color"][1] / 255., base["color"][2] / 255.)
            );
            match.teams.InsertLast(team);

            for (uint j = 0; j < t["members"].Length; j++) {
                auto player = t["members"][i];
                match.players.InsertLast(Player(PlayerProfile::Deserialize(player), team));
            }
        }

        @match.gameMaps = {};
        for (uint i = 0; i < value["cells"].Length; i++) {
            auto cell = value["cells"][i];
            match.gameMaps.InsertLast(GameMap::Deserialize(cell["map"]));
        }
        return match;
    }
}
