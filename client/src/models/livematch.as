
namespace LiveMatch {
    LiveMatch Deserialize(Json::Value@ value) {
        auto match = LiveMatch();
        match.config = MatchConfiguration::Deserialize(value["config"]);
        match.phase = MatchPhase(int(value["phase"]));
        match.startTime = Time::Now - (Time::Stamp + uint64(value["started"]));

        @match.teams = {};
        for (uint i = 0; i < value["teams"].Length; i++) {
            Json::Value@ t = value["teams"][i];
            Team team = Team(
                t["id"], 
                t["name"],
                vec3(t["color"][0] / 255., t["color"][1] / 255., t["color"][2] / 255.)
            );
            match.teams.InsertLast(team);
        }

        @match.gameMaps = {};
        for (uint i = 0; i < value["cells"].Length; i++) {
            auto cell = value["cells"][i];
            match.gameMaps.InsertLast(GameMap::Deserialize(cell["map"]));
        }
        return match;
    }
}
