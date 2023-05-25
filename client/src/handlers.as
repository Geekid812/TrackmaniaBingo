

namespace NetworkHandlers {
    void TeamsUpdate(Json::Value@ Status) {
        @Room.Teams = {};
        auto JsonTeams = Status["teams"];
        for (uint i = 0; i < JsonTeams.Length; i++){
            auto JsonTeam = JsonTeams[i];
            Room.Teams.InsertLast(Team(
                JsonTeam["id"],
                JsonTeam["name"], 
                vec3(JsonTeam["color"][0] / 255., JsonTeam["color"][1] / 255., JsonTeam["color"][2] / 255.)
            ));
        }
    }

    void PlayerUpdate(Json::Value@ Status) {
        auto uids = Status["updates"].GetKeys();
        for (uint i = 0; i < uids.Length; i++) {
            int uid = Text::ParseInt(uids[i]);
            Player@ player = Room.GetPlayer(uid);
            if (player is null) continue;
            player.Team = Room.GetTeamWithId(int(Status["updates"].Get(tostring(uid))));
        }
    }

    void LoadMaps(Json::Value@ mapList) {
        @Room.MapList = {};
        for (uint i = 0; i < mapList.Length; i++) {
            auto JsonMap = mapList[i];
            Room.MapList.InsertLast(Map(
                JsonMap["name"],
                JsonMap["author_name"],
                JsonMap["track_id"],
                JsonMap["uid"]
            ));
        }
    }

    void LoadGameData(Json::Value@ data) {
        Room.StartTime = Time::Now - uint(data["start_time"]);
        for (uint i = 0; i < data["cells"].Length; i++) {
            Json::Value@ cell = data["cells"][i];
            if (cell["claim"].GetType() == Json::Type::Null) continue;
            Room.MapList[i].ClaimedRun = RunResult(cell["claim"]["time"], Medal(int(cell["claim"]["medal"])));
            Room.MapList[i].ClaimedPlayerName = cell["claim"]["player"]["name"];
            @Room.MapList[i].ClaimedTeam = Room.GetTeamWithId(cell["claim"]["player"]["team"]);
        }
    }
}