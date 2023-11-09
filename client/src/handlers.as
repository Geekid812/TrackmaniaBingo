

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
        Match.uid = match["uid"];
        Match.startTime = Time::Now + uint64(match["start_ms"]);
        Match.teams = Room.teams;
        Match.players = Room.players;
        Match.config = Room.matchConfig;
        Match.canReroll = bool(match["can_reroll"]);
        LoadMaps(match["maps"]);
        UIGameRoom::GrabFocus = true;
        UIMapList::Visible = false;

        PersistantStorage::LastConnectedMatchId = Match.uid;
        Meta::SaveSettings(); // Ensure MatchId is saved, even in the event of a crash
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
                string teamCredit = "for " + teamName + " Team";
                if (Match.config.freeForAll) teamCredit = "";
                vec4 teamColor = UIColor::Brighten(UIColor::GetAlphaColor(team.color, 0.1), 0.75);
                vec4 dimmedColor = teamColor / 1.5;
                RunResult result = claim.result;
                
                if (isReclaim) {
                    UI::ShowNotification(Icons::Retweet + " Map Reclaimed", playerName + " has reclaimed \\$fd8" + mapName + "\\$z " + teamCredit + "\n" + result.Display() + " (" + deltaTime + ")", teamColor, 15000);
                } else if (isImprove) {
                    UI::ShowNotification(Icons::ClockO + " Time Improved", playerName + " has improved " + (Match.config.freeForAll ? "their" : (teamName + " Team's")) + " time on \\$fd8" + mapName + "\\$z\n" + result.Display() + " (" + deltaTime + ")", dimmedColor, 15000);
                } else { // Normal claim
                    UI::ShowNotification(Icons::Bookmark + " Map Claimed", playerName + " has claimed \\$fd8" + mapName + "\\$z " + teamCredit + "\n" + result.Display(), teamColor, 15000);
                }
            }
            claimedMap.RegisterClaim(claim);
    }

    void UpdateConfig(Json::Value@ data) {
        Room.config = RoomConfiguration::Deserialize(data["config"]);
        Room.matchConfig = MatchConfiguration::Deserialize(data["match_config"]);
    }

    void AddRoomListing(Json::Value@ room) {
        auto netRoom = NetworkRoom::Deserialize(room);
        UIRoomMenu::PublicRooms.InsertLast(netRoom);

        if (PersistantStorage::SubscribeToRoomUpdates && @Match is null && @Room is null) {
            array<string> params = {
                stringof(netRoom.matchConfig.selection),
                netRoom.matchConfig.gridSize + "x" + netRoom.matchConfig.gridSize,
                stringof(netRoom.matchConfig.targetMedal)
            };
            if (netRoom.matchConfig.timeLimit != 0) {
                params.InsertLast((netRoom.matchConfig.timeLimit / 60000) + " minutes");
            }
            string paramsString = string::Join(params, ", ");
            UI::ShowNotification(Icons::PlusCircle + " Bingo: New game started", netRoom.hostName + " is hosting a new game: \\$ee4" + netRoom.name + "\n\\$z(" + paramsString + ")", vec4(0.27,0.50,0.29, 1.), 10000);
        }
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

    void LoadRoomTeams(Json::Value@ teams) {
        @Room.teams = {};
        @Room.players = {};
        for (uint i = 0; i < teams.Length; i++) {
            Json::Value@ t = teams[i];
            Team team = Team(
                t["id"], 
                t["name"],
                vec3(t["color"][0] / 255., t["color"][1] / 255., t["color"][2] / 255.)
            );
            Room.teams.InsertLast(team);

            for (uint j = 0; j < t["members"].Length; j++) {
                Json::Value@ m = t["members"][j];
                PlayerProfile profile = PlayerProfile::Deserialize(m);
                Room.players.InsertLast(Player(profile, team));
            }
        }
    }

    void PlayerJoin(Json::Value@ data) {
        if (@Room is null) return;
        Room.players.InsertLast(Player(PlayerProfile::Deserialize(data["profile"]), Room.GetTeamWithId(data["team"])));
    }

    void PlayerLeave(Json::Value@ data) {
        int uid = int(data["uid"]);
        for (uint i = 0; i < Room.players.Length; i++) {
            if (Room.players[i].profile.uid == uid) {
                Room.players.RemoveAt(i);
                return;
            }
        }
    }

    void AnnounceBingo(Json::Value@ data) {
        @Match.endState.bingoLines = {};
        for (uint i = 0; i < data["lines"].Length; i++) {
            auto value = data["lines"][i];
            BingoLine line = BingoLine();
            int team_id = int(value["team"]);

            line.offset = value["index"];
            line.bingoDirection = BingoDirection(int(value["direction"]));
            line.team = Match.GetTeamWithId(team_id);
            Match.endState.bingoLines.InsertLast(line);
        }
        if (Match.endState.bingoLines.Length == 0) {
            throw("Received empty bingo lines!");
        }

        uint winningTeamsCount = Match.endState.WinnerTeamsCount();
        string textContent;
        if (winningTeamsCount == 1) {
            Team team = Match.endState.bingoLines[0].team;
            @Match.endState.team = team;
            string teamName = "\\$" + UIColor::GetHex(team.color) + team.name;
            textContent = teamName + "\\$z has won the game!";
        } else {
            textContent = winningTeamsCount + " teams have managed to get a bingo. Congratulations!";
        }
        UI::ShowNotification(Icons::Trophy + " Bingo!", textContent, vec4(.9, .6, 0, 1), 20000);

        Match.endState.endTime = Time::Now;
        Match.SetPhase(MatchPhase::Ended);
        PersistantStorage::LastConnectedMatchId = "";
    }

    void TeamCreated(Json::Value@ data) {
        Room.teams.InsertLast(Team(
            data["id"], 
            data["name"],
            vec3(data["color"][0] / 255., data["color"][1] / 255., data["color"][2] / 255.)
        ));
    }

    void TeamDeleted(Json::Value@ data) {
        int id = data["id"];
        for (uint i = 0; i < Room.teams.Length; i++) {
            if (Room.teams[i].id == id) {
                Room.teams.RemoveAt(i);
                return;
            }
        }
    }

    void PhaseChange(Json::Value@ data) {
        if (@Match is null) {
            warn("Handlers [PhaseChange]: Match is null!");
            return;
        }
        Match.SetPhase(MatchPhase(int(data["phase"])));
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

    void LoadDailyChallenge(Json::Value@ data) {
        if (data is null) {
            UIDaily::DailyLoad = LoadStatus::Error;
            return;
        }

        UIDaily::DailyLoad = LoadStatus::Ok;
        if (data["res"] == "DailyNotLoaded") {
            @UIDaily::DailyMatch = null;
            return;
        }

        LiveMatch match = LiveMatch::Deserialize(data["state"]);
        @UIDaily::DailyMatch = match;
    }

    void RoomSync(Json::Value@ data) {
        Room.config = RoomConfiguration::Deserialize(data["config"]);
        Room.matchConfig = MatchConfiguration::Deserialize(data["matchconfig"]);
        Room.joinCode = data["join_code"];
        LoadRoomTeams(data["teams"]);
    }

    void MatchSync(Json::Value@ data) {
        warn("TODO: MatchSync");
    }

    void AnnounceWinByCellCount(Json::Value@ data) {
        Team team = Match.GetTeamWithId(int(data["team"]));
        string teamName = "\\$" + UIColor::GetHex(team.color) + team.name;
        uint cellCount = Match.GetTeamCellCount(team);
        UI::ShowNotification(Icons::HourglassEnd + " Game End", teamName + "\\$z has won the game by claiming the most maps, with a total of " + cellCount + " maps!", vec4(.9, .6, 0, 1), 20000);

        Match.endState.endTime = Time::Now;
        @Match.endState.team = team;
        Match.SetPhase(MatchPhase::Ended);
        PersistantStorage::LastConnectedMatchId = "";
    }

    void AnnounceDraw() {
        UI::ShowNotification(Icons::HourglassEnd + " Game End", "The game has ended in a tie.", vec4(.5, .5, .5, 1), 20000);

        Match.endState.endTime = Time::Now;
        Match.SetPhase(MatchPhase::Ended);
        PersistantStorage::LastConnectedMatchId = "";
    }

    void MatchTeamCreated(Json::Value@ data) {
        Match.teams.InsertLast(Team(
            data["id"], 
            data["name"],
            vec3(data["color"][0] / 255., data["color"][1] / 255., data["color"][2] / 255.)
        ));
    }

    void MatchPlayerJoin(Json::Value@ data) {
        if (@Match is null) return;
        Match.players.InsertLast(Player(PlayerProfile::Deserialize(data["profile"]), Match.GetTeamWithId(data["team"])));
    }

    void RerollVoteCast(Json::Value@ data) {
        if (@Match is null) {
            warn("Handlers: got RerollVoteCast event but Match is null.");
            return;
        }

        uint id = uint(data["cell_id"]);
        uint player_id = uint(data["player_id"]);
        MapCell cell = Match.GetCell(id);
        if (bool(data["added"])) {
            cell.rerollIds.InsertLast(player_id);

            int count = uint(data["count"]);
            int required = uint(data["required"]);
            string trackName = ColoredString(cell.map.trackName);
            Player player = Match.GetPlayer(player_id);
            string playerTag = "\\$" + UIColor::GetHex(player.team.color) + player.name; 
            UI::ShowNotification("", Icons::Kenney::ReloadInverse + " " + playerTag + " \\$zhas voted to reroll \\$fd8" + trackName + " \\$z(" + count + "/" + required + ")", vec4(0., .4, .4, 1.), 10000);
        } else {
            for (uint i = 0; i < cell.rerollIds.Length; i++) {
                if (cell.rerollIds[i] == player_id) cell.rerollIds.RemoveAt(i);
            }
        }
    }

    void MapRerolled(Json::Value@ data) {
        if (@Match is null) {
            warn("Handlers: got MapRerolled event but Match is null.");
            return;
        }

        uint id = uint(data["cell_id"]);
        string oldName = ColoredString(Match.gameMaps[id].map.trackName);
        Match.gameMaps.RemoveAt(id);
        Match.gameMaps.InsertAt(id, MapCell(GameMap::Deserialize(data["map"])));
        Match.canReroll = bool(data["can_reroll"]);

        UI::ShowNotification(Icons::Kenney::ReloadInverse + " Map Rerolled", "The map \\$fd8" + oldName + " \\$zhas been rerolled.", vec4(0., .6, .6, 1.), 10000);
    }
}
