

namespace NetworkHandlers {
    void UpdateRoom(Json::Value@ Status) {
        string LocalUsername = cast<CTrackManiaNetwork@>(GetApp().Network).PlayerInfo.Name;
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

        @Room.Players = {};
        for (uint i = 0; i < Status["members"].Length; i++) {
            auto JsonPlayer = Status["members"][i];
            Room.Players.InsertLast(Player(
                JsonPlayer["name"],
                Room.GetTeamWithId(int(JsonPlayer["team"])),
                JsonPlayer["name"] == LocalUsername
            ));
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
        InfoBar::StartTime = Time::Now - uint(data["start_time"]);
        for (uint i = 0; i < data["cells"].Length; i++) {
            Json::Value@ cell = data["cells"][i];
            if (cell["claim"].GetType() == Json::Type::Null) continue;
            Room.MapList[i].ClaimedRun = RunResult(cell["claim"]["time"], Medal(int(cell["claim"]["medal"])));
            Room.MapList[i].ClaimedPlayerName = cell["claim"]["player"]["name"];
            @Room.MapList[i].ClaimedTeam = Room.GetTeamWithId(cell["claim"]["player"]["team"]);
        }
    }
}