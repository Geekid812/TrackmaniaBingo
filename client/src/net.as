
namespace Network {
    const int SECRET_LENGTH = 32;

    namespace Internal {
        // Disable UI interactions while a blocking request is happening
        bool SuspendUI = false;
        // Connection indicator
        bool IsConnected = false;
        // Offline mode indicator
        bool OfflineMode = false;
        // Sequence counter
        uint SequenceNext = 0;
        // Temporary buffer of server request messages
        array<Response@> Received = {};
    }
    namespace Timings {
        // Timestamp of last ping sent
        uint64 LastPingSent = 0;
        // Timestamp of last ping recv
        uint64 LastPingReceived = 0;
    }

    // Internal socket manager
    Protocol _protocol;

    class Response {
        uint sequence;
        Json::Value@ body;

        Response(uint seq, Json::Value@ body) {
            this.sequence = seq;
            @this.body = body;
        }
    }

    void Reset() {
        _protocol = Protocol();
        Internal::SuspendUI = false;
        Internal::IsConnected = false;
        Internal::OfflineMode = false;
        Internal::SequenceNext = 0;
        Internal::Received = {};
        Timings::LastPingSent = 0;
        Timings::LastPingReceived = 0;
    }

    void Connect() {
        SetOfflineMode(false);

        Login::EnsureLoggedIn();
        if (!Login::IsLoggedIn()) {
            SetOfflineMode(true);
            return;
        }
        Timings::LastPingSent = Time::Now;
        Timings::LastPingReceived = Time::Now;
        OpenConnection();
        SetOfflineMode(!IsConnected());
    }

    bool IsOfflineMode() {
        return Internal::OfflineMode;
    }

    void SetOfflineMode(bool offline) {
        Internal::OfflineMode = offline;
    }

    bool IsConnected() {
        return _protocol.state == ConnectionState::Connected;
    }

    ConnectionState GetState() {
        return _protocol.state;
    }

    bool IsUISuspended() {
        return Internal::SuspendUI;
    }

    void OpenConnection() {
        int retries = 3;
        while (!IsConnected() && retries > 0) {
            auto handshake = HandshakeData();
            handshake.clientVersion = Meta::ExecutingPlugin().Version;
            handshake.username = GetLocalLogin();
            handshake.authToken = PersistantStorage::ClientToken;
            int code = _protocol.Connect(Settings::BackendAddress, Settings::NetworkPort, handshake);
            if (code != -1) HandleHandshakeCode(HandshakeCode(code));

            if (!IsConnected()) {
                retries -= 1;
                trace("Network: Failed to connect. " + retries + " retry attempts left.");
            }
        }
    }

    void HandleHandshakeCode(HandshakeCode code) {
        if (code == HandshakeCode::Ok) {
            WasConnected = false;
            return;
        }
        if (code == HandshakeCode::CanReconnect) {
            // The server indicates that reconnecting is possible
            trace("Network: Received reconnection handshake code, attempting to reconnect.");
            UI::ShowNotification(Icons::Globe + " Reconnecting...");
            startnew(Sync);
        } else if (code == HandshakeCode::IncompatibleVersion) {
            // Update required
            UI::ShowNotification(Icons::Upload + " Update Required!", "A new update is required to play Bingo. Please update the plugin to the latest version in the plugin manager.", vec4(.4, .4, 1., 1.), 10000);
        } else if (code == HandshakeCode::AuthRefused || code == HandshakeCode::AuthFailure) {
            // Auth error (we should try and update our logins)
            trace("Network: Received auth error handshake code (" + code + "). Attempting to refresh credentials...");
            Login::Login();
        } else {
            // Plugin error (this should not happen)
        }
    }

    void Loop() {
        if (!IsConnected()) return;
        
        string message = _protocol.Recv();
        while (message != "") {
            trace("Network: Received message: " + message);
            Json::Value json;
            try {
                json = Json::Parse(message);
            } catch {
                trace("Network: Failed to parse received message. Got: " + message);
                _protocol.Fail();
                break;
            }

            Handle(json);

            message = _protocol.Recv();
        }

        if (Timings::LastPingSent + Settings::PingInterval <= Time::Now) {
            startnew(DoPing);
            Timings::LastPingSent = Time::Now;
        }

        if (Timings::LastPingReceived + Settings::PingInterval + Settings::NetworkTimeout <= Time::Now) {
            OnDisconnect();
        }
    }

    void DoPing() {
        if (@Post("Ping", Json::Object(), false) != null) {
            Timings::LastPingReceived = Time::Now;
        }
    }

    void OnDisconnect() {
        trace("Network: Disconnected! Attempting to reconnect...");
        Reset();
        Connect();
        if (!IsConnected()) {
            Reset();
            UI::ShowNotification(Icons::Exclamation + " Bingo: You have been disconnected!", "Use the plugin interface to reconnect.", vec4(.9, .1, .1, 1.), 10000);
            Internal::OfflineMode = true;
        } else {
            trace("Network: Reconnected to server.");
        }
    }

    void TestConnection() {
        uint64 start = Time::Now;
        auto response = Post("Ping", Json::Object(), false);
        uint64 end = Time::Now - start;
        bool result = response !is null;
        trace("TestConnection: " + tostring(result) + " in " + end + "ms");
    }

    void Handle(Json::Value@ body) {
        if (body.HasKey("seq")) {
            uint SequenceCode = body["seq"];
            Response@ res = Response(SequenceCode, body);
            Internal::Received.InsertLast(res);
            yield();
            return;
        }
        if (!body.HasKey("event")) {
            warn("Invalid message, discarding.");
            return;
        }
        if (@Room == null) return;
        if (body["event"] == "PlayerUpdate") {
            NetworkHandlers::PlayerUpdate(body);
        } /* else if (Body["event"] == "RoomConfigUpdate") {
            uint oldGridSize = Room.config.GridSize;
            MapMode oldMode = Room.config.MapSelection;
            Room.config = Deserialize(Body);
            if (oldGridSize < Room.config.GridSize || oldMode != Room.config.MapSelection) Room.MapsLoadingStatus = LoadStatus::Loading;
        } else if (Body["event"] == "MapsLoadResult") {
            if (Body["error"].GetType() != Json::Type::Null) {
                Room.MapsLoadingStatus = LoadStatus::LoadFail;
                Room.LoadFailInfo = Body["error"];
            } else {
                Room.MapsLoadingStatus = LoadStatus::LoadSuccess;
            }
        } else if (Body["event"] == "GameStart") {
            NetworkHandlers::LoadMaps(Body["maps"]);
            Room.StartTime = Time::Now;
            WasConnected = true;
            Meta::SaveSettings(); // Ensure WasConnected is saved, even in the event of a crash
        } else if (Body["event"] == "CellClaim") {
            MapCell@ claimedMap = Match.gameMaps[Body["cell_id"]];
            RunResult result = RunResult(int(Body["claim"]["time"]), Medal(int(Body["claim"]["medal"])));
            Team team = Room.GetTeamWithId(int(Body["claim"]["player"]["team"]));

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
        } else if (Body["event"] == "AnnounceBingo") {
            Team team = Room.GetTeamWithId(int(Body["team"]));
            string TeamName = "\\$" + UIColor::GetHex(team.Color) + team.Name;
            UI::ShowNotification(Icons::Trophy + " Bingo!", TeamName + "\\$z has won the game!", vec4(.6, .6, 0, 1), 20000);

            Room.EndState.BingoDirection = BingoDirection(int(Body["direction"]));
            Room.EndState.Offset = Body["index"];
            Room.EndState.EndTime = Time::Now;
            WasConnected = false;
        } else if (Body["event"] == "Trace") {
            // Message is already logged to the console
            // trace("Trace: " + string(Body["value"]));
        } */
    }

    void CloseConnection() {
        Reset();
        trace("Connection closed cleanly.");
    }

    int AddSequenceValue(Json::Value@ val) {
        uint seq = Internal::SequenceNext;
        val["seq"] = seq;
        Internal::SequenceNext += 1;
        return seq;
    }

    Json::Value@ ExpectReply(uint SequenceCode, uint timeout = 5000) {
        uint64 timeoutDate = Time::Now + timeout;
        Json::Value@ message = null;
        while (Time::Now < timeoutDate && @message is null) {
            yield();
            for (uint i = 0; i < Internal::Received.Length; i++) {
                auto msg = Internal::Received[i];
                if (msg.sequence == SequenceCode) {
                    @message = msg.body;
                    Internal::Received.RemoveAt(i);
                    break;       
                }
            }
        }
        return message;
    }

    Json::Value@ Post(string&in type, Json::Value@ body, bool blocking = false, uint timeout = 5000) {
        body["req"] = type;
        uint Sequence = AddSequenceValue(body);
        string Text = Json::Write(body);
        if (!_protocol.Send(Text)) {
            warn("Network: Post preemptively failed!");
            return null;
        } // TODO: connection fault?
        Internal::SuspendUI = blocking;
        Json::Value@ reply = ExpectReply(Sequence, timeout);
        if (blocking) Internal::SuspendUI = false;

        if (reply !is null && reply.HasKey("error")) {
            trace("Request [" + type + "]: Error: " + string(reply["error"]));
            UI::ShowNotification("", Icons::Times + " Error in " + type + ": " + string(reply["error"]), vec4(.8, 0., 0., 1.), 10000);
            return null;
        }
        return reply;
    }

    void CreateRoom() {
        auto body = RoomConfiguration::Serialize(RoomConfig);

        Json::Value@ response = Post("CreateRoom", body, true);
        if (response is null) {
            trace("Network: CreateRoom - No reply from server.");
            Reset();
            return;
        }

        // The room was created. Setting up room status (local player is host)
        @Room = GameRoom();
        Room.config = RoomConfig;
        string roomCode = response["join_code"];
        Room.maxTeams = int(response["max_teams"]);
        UIRoomMenu::JoinCodeVisible = false;
        UIMainWindow::Visible = false;
        UIGameRoom::Visible = true;

        Room.teams = {};
        auto jsonTeams = response["teams"];
        for (uint i = 0; i < jsonTeams.Length; i++) {
            auto JsonTeam = jsonTeams[i];
            Room.teams.InsertLast(Team(
                JsonTeam["id"], 
                JsonTeam["name"],
                vec3(JsonTeam["color"][0] / 255., JsonTeam["color"][1] / 255., JsonTeam["color"][2] / 255.)
            ));
        }

        Room.name = response["name"];
        Room.localPlayerIsHost = true;
        Room.joinCode = roomCode;
        @Room.players = { Player(Profile, Room.teams[0], true) };
    }

    void CreateTeam() {
        Network::Post("CreateTeam", Json::Object());
    }

    void JoinRoom() {
        auto body = Json::Object();
        body["join_code"] = NetParams::JoinCode;

        auto response = Post("JoinRoom", body, true);
        if (response is null) {
            trace("Network: JoinRoom - No reply from server.");
            Reset();
            return;
        }
        
        if (response.HasKey("error")) {
            UI::ShowNotification(Icons::Times + string(response["error"]));  
        } else {
            // Success!
            @Room = GameRoom();
            Room.name = response["name"];
            Room.config = RoomConfiguration::Deserialize(response["config"]);
            Room.joinCode = UIRoomMenu::JoinCodeInput;
            Room.localPlayerIsHost = false;
            //NetworkHandlers::UpdateRoom(Response["status"]);

            UIRoomMenu::JoinCodeVisible = false;
        }
    }

    void GetPublicRooms() {
        auto response = Post("GetPublicRooms", Json::Object(), false);
        if (response is null) {
            trace("Network: GetPublicRooms - No reply from server.");
            UIRoomMenu::RoomsLoad = UIRoomMenu::LoadStatus::Error;
            return;
        }
        
        auto rooms = array<UIRoomMenu::PublicRoom>();
        for (uint i = 0; i < response["rooms"].Length; i++) {
            rooms.InsertLast(UIRoomMenu::PublicRoom(response["rooms"][i])); 
        }
        UIRoomMenu::Rooms = rooms;
        UIRoomMenu::RoomsLoad = UIRoomMenu::LoadStatus::Ok;
    }

    void EditRoomSettings() {
        auto body = Json::Object();
        body["config"] = RoomConfiguration::Serialize(RoomConfig);

        auto response = Post("EditRoomConfig", body, true);
        if (response is null) {
            trace("Network: EditRoomSettings - No reply from server.");
            Reset();
            return;
        }
        
        if (response.HasKey("error")) {
            UI::ShowNotification(Icons::Times + string(response["error"]));  
        } else {
            SettingsWindow::Visible = false;
        }
    }

    void LeaveRoom() {
        // TODO: this is rudimentary, it doesn't keep connection alive
        @Room = null;
        CloseConnection();
    }

    void JoinTeam(Team team) {
        if (Room.GetSelf().team == team)
            return;

        auto body = Json::Object();
        body["team_id"] = team.id;
        startnew(function(ref@ body) {
            Post("ChangeTeam", cast<Json::Value@>(body));
        }, body);
    }

    void StartMatch() {
        Post("StartMatch", Json::Object(), true);
    }

    bool ClaimCell(string&in uid, RunResult result) {
        auto body = Json::Object();
        body["uid"] = uid;
        body["time"] = result.time;
        body["medal"] = result.medal;
        auto Request = Network::Post("ClaimCell", body, false);
        return Request !is null;
    }

    void Sync() {
        trace("Network: Syncing with server...");
        auto response = Network::Post("Sync", Json::Object(), false);
        if (response is null) {
            trace("Sync: No reply from server.");
            WasConnected = false;
            return;
        }
        @Room = GameRoom();
        Room.name = response["room_name"];
        Room.config = RoomConfiguration::Deserialize(response["config"]);
        Room.joinCode = response["join_code"];
        Room.localPlayerIsHost = response["host"];
        //NetworkHandlers::UpdateRoom(response["status"]);
        NetworkHandlers::LoadMaps(response["maps"]);
        if (response.HasKey("game_data")) {
            NetworkHandlers::LoadGameData(response["game_data"]);
        }
    }

    void NotifyCountdownEnd() {
        // TODO
    }
}
