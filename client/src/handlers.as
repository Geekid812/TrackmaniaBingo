

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

    void RunSubmitted(Json::Value@ data) {
            MapCell@ claimedMap = Match.GetCell(int(data["cell_id"]));
            int position = int(data["position"]);
            MapClaim claim = MapClaim::Deserialize(data["claim"]);

            if (position == 1) {
                auto team = claim.player.team;
                bool isImprove = claimedMap.IsClaimed() && claimedMap.LeadingRun().player.team.id == team.id;
                bool isReclaim = claimedMap.IsClaimed() && claimedMap.LeadingRun().player.team.id != team.id;
                string deltaTime = claimedMap.IsClaimed() ? "-" + Time::Format(claimedMap.LeadingRun().result.time - claim.result.time) : "";
                string playerName = claim.player.name;
                string mapName = ColoredString(claimedMap.map.trackName);
                string teamName = team.name;
                vec4 teamColor = UIColor::Brighten(UIColor::GetAlphaColor(team.color, 0.1), 0.75);
                vec4 dimmedColor = teamColor / 1.5;
                RunResult result = claim.result;
                
                if (isReclaim) {
                    UI::ShowNotification(Icons::Retweet + " Map Reclaimed", playerName + " has reclaimed \\$fd8" + mapName + "\\$z for " + teamName + " Team\n" + result.Display() + " (" + deltaTime + ")", teamColor, 15000);
                } else if (isImprove) {
                    UI::ShowNotification(Icons::ClockO + " Time Improved", playerName + " has improved " + teamName + " Team's time on \\$fd8" + mapName + "\\$z\n" + result.Display() + " (" + deltaTime + ")", dimmedColor, 15000);
                } else { // Normal claim
                    UI::ShowNotification(Icons::Bookmark + " Map Claimed", playerName + " has claimed \\$fd8" + mapName + "\\$z for " + teamName + " Team\n" + result.Display(), teamColor, 15000);
                }
            }
            claimedMap.RegisterClaim(claim);
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

    void RoomlistUpdateConfig(Json::Value@ data) {
        NetworkRoom@ room = UIRoomMenu::GetRoom(data["code"]);
        room.config = RoomConfiguration::Deserialize(data["config"]);
        room.matchConfig = MatchConfiguration::Deserialize(data["match_config"]);
    }

    void RoomlistPlayerUpdate(Json::Value@ data) {
        NetworkRoom@ room = UIRoomMenu::GetRoom(data["code"]);
        room.playerCount += int(data["delta"]);
    }

    void RoomlistInGameStatusUpdate(Json::Value@ data) {
        NetworkRoom@ room = UIRoomMenu::GetRoom(data["code"]);
        room.startedTimestamp = uint64(data["start_time"]);
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