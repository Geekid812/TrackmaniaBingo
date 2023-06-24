

namespace NetworkHandlers {
    void TeamsUpdate(Json::Value@ status) {
        @Room.teams = {};
        auto JsonTeams = status["teams"];
        for (uint i = 0; i < JsonTeams.Length; i++){
            auto JsonTeam = JsonTeams[i];
            Room.teams.InsertLast(Team(
                JsonTeam["id"],
                JsonTeam["name"], 
                UIColor::FromRgb(JsonTeam["color"][0], JsonTeam["color"][1], JsonTeam["color"][2])
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

    void RunSubmitted(Json::Value@ claim) {
            MapCell@ claimedMap = Match.GetCell(int(claim["cell_id"]));
            int position = int(claim["position"]);
            claimedMap.attemptRanking.InsertAt(position - 1, MapClaim::Deserialize(claim["claim"]));

/**
            bool IsImprove = claimedMap.ClaimedTeam !is null && claimedMap.ClaimedTeam.Id == team.Id;
            bool IsReclaim = claimedMap.ClaimedTeam !is null && claimedMap.ClaimedTeam.Id != team.Id;
            string DeltaTime = claimedMap.ClaimedRun.Time == -1 ? "" : "-" + Time::Format(claimedMap.ClaimedRun.Time - result.Time);
            string PlayerName = Body["claim"]["player"]["name"];
            @claimedMap.ClaimedTeam = @team;
            claimedMap.ClaimedRun = result;
            claimedMap.ClaimedPlayerName = PlayerName;

            string MapName = claimedMap.Name;
            string TeamName = team.Name;
            vec4 TeamColor = UIColor::Brighten(UIColor::GetAlphaColor(team.Color, 0.1), 0.75);
            vec4 DimmedColor = TeamColor / 1.5;
            
            if (IsReclaim) {
                UI::ShowNotification(Icons::Retweet + " Map Reclaimed", PlayerName + " has reclaimed \\$fd8" + MapName + "\\$z for " + TeamName + " Team\n" + result.Display() + " (" + DeltaTime + ")", TeamColor, 15000);
            } else if (IsImprove) {
                UI::ShowNotification(Icons::ClockO + " Time Improved", PlayerName + " has improved " + TeamName + " Team's time on \\$fd8" + MapName + "\\$z\n" + result.Display() + " (" + DeltaTime + ")", DimmedColor, 15000);
            } else { // Normal claim
                UI::ShowNotification(Icons::Bookmark + " Map Claimed", PlayerName + " has claimed \\$fd8" + MapName + "\\$z for " + TeamName + " Team\n" + result.Display(), TeamColor, 15000);
            }   
            */
    }

    void UpdateConfig(Json::Value@ data) {
        Room.config = RoomConfiguration::Deserialize(data["config"]);
        Room.matchConfig = MatchConfiguration::Deserialize(data["match_config"]);
    }

    void AddRoomListing(Json::Value@ room) {
        UIRoomMenu::PublicRooms.InsertLast(NetworkRoom::Deserialize(room));
    }

    void RemoveRoomListing(Json::Value@ data) {
        string joinCode = data["join_code"];
        for (uint i = 0; i < UIRoomMenu::PublicRooms.Length; i++) {
            NetworkRoom current = UIRoomMenu::PublicRooms[i];
            if (current.joinCode == joinCode) {
                UIRoomMenu::PublicRooms.RemoveAt(i);
                return;
            }
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