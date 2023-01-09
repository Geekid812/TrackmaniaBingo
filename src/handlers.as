

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
}