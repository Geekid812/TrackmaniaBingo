

namespace NetworkHandlers {
    void TeamsUpdate(Json::Value@ status) {
        @Room.teams = {};
        auto JsonTeams = status["teams"];
        for (uint i = 0; i < JsonTeams.Length; i++){
            auto JsonTeam = JsonTeams[i];
            Room.teams.InsertLast(Team(
                JsonTeam["id"],
                JsonTeam["name"], 
                vec3(JsonTeam["color"][0] / 255., JsonTeam["color"][1] / 255., JsonTeam["color"][2] / 255.)
            ));
        }
    }

    void PlayerUpdate(Json::Value@ status) {
        auto uids = status["updates"].GetKeys();
        for (uint i = 0; i < uids.Length; i++) {
            int uid = Text::ParseInt(uids[i]);
            Player@ player = Room.GetPlayer(uid);
            if (player is null) continue;
            player.team = Room.GetTeamWithId(int(status["updates"].Get(tostring(uid))));
        }
    }

    void MatchStart(Json::Value@ match) {
        @Match = LiveMatch();
        Match.startTime = Time::Now + uint64(match["start_ms"]);
        Match.teams = Room.teams;
        Match.players = Room.players;
        Match.config = Room.matchConfig;
        LoadMaps(match["maps"]);
        WasConnected = true;
        Meta::SaveSettings(); // Ensure WasConnected is saved, even in the event of a crash
    }

    void LoadMaps(Json::Value@ mapList) {
        @Match.gameMaps = {};
        for (uint i = 0; i < mapList.Length; i++) {
            auto jsonMap = mapList[i];
            Match.gameMaps.InsertLast(GameMap::Deserialize(jsonMap));
        }
    }

    void LoadGameData(Json::Value@ data) {
//        Room.StartTime = Time::Now - uint(data["start_time"]);
        for (uint i = 0; i < data["cells"].Length; i++) {
            Json::Value@ cell = data["cells"][i];
            if (cell["claim"].GetType() == Json::Type::Null) continue;
//            Room.MapList[i].ClaimedRun = RunResult(cell["claim"]["time"], Medal(int(cell["claim"]["medal"])));
//            Room.MapList[i].ClaimedPlayerName = cell["claim"]["player"]["name"];
//            @Room.MapList[i].ClaimedTeam = Room.GetTeamWithId(cell["claim"]["player"]["team"]);
        }
    }
}