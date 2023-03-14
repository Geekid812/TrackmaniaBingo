
namespace Network {
    const int SECRET_LENGTH = 16;

    // Server TCP socket listening for events
    Net::Socket@ EventStream = Net::Socket();
    // Suspend UI while a blocking request is happening
    bool RequestInProgress = false;
    // Indicator if Network::Init() has been called 
    bool IsInitialized = false;
    // Loop running indicator
    bool IsLooping = false;
    // Connection indicator
    bool IsConnected = false;

    Protocol _protocol;
    string AuthToken;
    uint64 TokenExpireDate;
    bool IsOffline;
    uint SequenceNext;
    array<Response@> Received;
    uint64 LastPingSent;
    uint64 LastPingReceived;

    class Response {
        uint Sequence;
        Json::Value@ Body;

        Response(uint seq, Json::Value@ body) {
            Sequence = seq;
            @Body = body;
        }
    }

    void Init() {
        IsInitialized = true;
        _protocol = Protocol();
        TokenExpireDate = 0;
        SequenceNext = 0;
        Received = {};
        Connect();
    }

    void Connect() {
        IsOffline = false;
        FetchAuthToken();
        LastPingSent = Time::Now;
        LastPingReceived = Time::Now;
        IsOffline = !OpenConnection();
    }

    ConnectionState GetState() {
        return _protocol.State;
    }

    void FetchAuthToken() {
        trace("Network: fetching a new authentication token...");
        Auth::PluginAuthTask@ task = Auth::GetToken();
        while (!task.Finished()) { yield(); }
        
        string token = task.Token();
        if (token != "") {
            AuthToken = token;
            TokenExpireDate = Time::Now + (5 * 60 * 1000); // Valid for 5 minutes
            trace("Network: received new authentication token.");
        } else {
            trace("Network: did not receive a valid token. This could be a connection issue.");
        }
    }

    bool OpenConnection() {
        auto handshake = HandshakeData();
        handshake.ClientVersion = Meta::ExecutingPlugin().Version.Split("-")[0];
        if (Time::Now > TokenExpireDate) {
            trace("Network: could not open a connection: authentication token is not valid.");
            return false;
        }
        handshake.AuthToken = AuthToken;
        handshake.Username = GetLocalLogin();

        int retries = 3;
        while (_protocol.State != ConnectionState::Connected && retries > 0) {
            int code = _protocol.Connect(Settings::BackendAddress, Settings::NetworkPort, handshake);
            if (code != -1) HandleHandshakeCode(HandshakeCode(code));

            if (_protocol.State != ConnectionState::Connected) {
                retries -= 1;
                trace("Network: Failed to connect. " + retries + " retry attempts left.");
            }
        }
        return _protocol.State == ConnectionState::Connected;
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
        } else if (code == HandshakeCode::AuthFailure) {
            // Auth servers are not reachable
        } else {
            // Plugin error (this should not happen)
        }
    }

    void Loop() {
        if (_protocol.State != ConnectionState::Connected) return;
        
        string Message = _protocol.Recv();
        while (Message != "") {
            trace("Network: Received message: " + Message);
            Json::Value Json;
            try {
                Json = Json::Parse(Message);
            } catch {
                trace("Network: Failed to parse received message. Got: " + Message);
                _protocol.Fail();
                break;
            }

            Handle(Json);

            Message = _protocol.Recv();
        }

        if (LastPingSent + Settings::PingInterval <= Time::Now) {
            startnew(function() {
                if (@Post("Ping", Json::Object(), false, Settings::NetworkTimeout) != null) {
                    Network::LastPingReceived = Time::Now;
                }
            });
            LastPingSent = Time::Now;
        }

        if (LastPingReceived + Settings::PingInterval + Settings::NetworkTimeout <= Time::Now) {
            OnDisconnect();
        }
    }

    void OnDisconnect() {
        trace("Network: Disconnected! Attempting to reconnect...");
        _protocol.State = ConnectionState::Closed;
        Connect();
        if (IsOffline) {
            Reset();
            UI::ShowNotification(Icons::Exclamation + " Bingo: You have been disconnected!", "Use the plugin interface to reconnect.", vec4(.9, .1, .1, 1.), 10000);
            IsOffline = true;
        } else {
            trace("Network: Reconnected to server.");
        }
    }

    bool Connected() {
        return _protocol.State == ConnectionState::Connected;
    }

    void TestConnection() {
        uint64 start = Time::Now;
        auto response = Post("Ping", Json::Object(), false);
        uint64 end = Time::Now - start;
        bool result = response !is null;
        trace("TestConnection: " + tostring(result) + " in " + end + "ms");
    }

    void Handle(Json::Value@ Body) {
        if (Body.HasKey("seq")) {
            uint SequenceCode = Body["seq"];
            Response@ res = Response(SequenceCode, Body);
            Received.InsertLast(res);
            yield();
            return;
        }
        if (!Body.HasKey("event")) {
            warn("Invalid message, discarding.");
            return;
        }
        if (@Room == null) return;
        if (Body["event"] == "RoomUpdate") {
            NetworkHandlers::UpdateRoom(Body);
        } else if (Body["event"] == "RoomConfigUpdate") {
            uint oldGridSize = Room.Config.GridSize;
            MapMode oldMode = Room.Config.MapSelection;
            Room.Config = Deserialize(Body);
            if (oldGridSize < Room.Config.GridSize || oldMode != Room.Config.MapSelection) Room.MapsLoadingStatus = LoadStatus::Loading;
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
            Map@ ClaimedMap = Room.MapList[Body["cell_id"]];
            RunResult Result = RunResult(int(Body["claim"]["time"]), Medal(int(Body["claim"]["medal"])));
            Team team = Room.GetTeamWithId(int(Body["claim"]["player"]["team"]));

            bool IsImprove = ClaimedMap.ClaimedTeam !is null && ClaimedMap.ClaimedTeam.Id == team.Id;
            bool IsReclaim = ClaimedMap.ClaimedTeam !is null && ClaimedMap.ClaimedTeam.Id != team.Id;
            string DeltaTime = ClaimedMap.ClaimedRun.Time == -1 ? "" : "-" + Time::Format(ClaimedMap.ClaimedRun.Time - Result.Time);
            string PlayerName = Body["claim"]["player"]["name"];
            @ClaimedMap.ClaimedTeam = @team;
            ClaimedMap.ClaimedRun = Result;
            ClaimedMap.ClaimedPlayerName = PlayerName;

            string MapName = ClaimedMap.Name;
            string TeamName = team.Name;
            vec4 TeamColor = UIColor::Brighten(UIColor::GetAlphaColor(team.Color, 0.1), 0.75);
            vec4 DimmedColor = TeamColor / 1.5;
            
            if (IsReclaim) {
                UI::ShowNotification(Icons::Retweet + " Map Reclaimed", PlayerName + " has reclaimed \\$fd8" + MapName + "\\$z for " + TeamName + " Team\n" + Result.Display() + " (" + DeltaTime + ")", TeamColor, 15000);
            } else if (IsImprove) {
                UI::ShowNotification(Icons::ClockO + " Time Improved", PlayerName + " has improved " + TeamName + " Team's time on \\$fd8" + MapName + "\\$z\n" + Result.Display() + " (" + DeltaTime + ")", DimmedColor, 15000);
            } else { // Normal claim
                UI::ShowNotification(Icons::Bookmark + " Map Claimed", PlayerName + " has claimed \\$fd8" + MapName + "\\$z for " + TeamName + " Team\n" + Result.Display(), TeamColor, 15000);
            }   
        } else if (Body["event"] == "AnnounceBingo") {
            Team team = Room.GetTeamWithId(int(Body["team"]));
            string TeamName = "\\$" + UIColor::GetHex(team.Color) + team.Name;
            UI::ShowNotification(Icons::Trophy + " Bingo!", TeamName + "\\$z has won the game!", vec4(.6, .6, 0, 1), 20000);

            Room.EndState.BingoDirection = BingoDirection(int(Body["direction"]));
            Room.EndState.Offset = Body["index"];
            Room.EndState.EndTime = Time::Now;
            WasConnected = false;
        } else if (Body["method"] == "MAPS_LOAD_STATUS") {
            Room.MapsLoadingStatus = LoadStatus(int(Body["status"]));
        } else if (Body["method"] == "ROOM_CLOSED"){
            CloseConnection();
            UI::ShowNotification(Icons::Info + " The host has disconnected.");
        }
    }

    void CloseConnection() {
        Reset();
        trace("Connection closed cleanly.");
    }

    void Reset() {
        EventStream.Close();
        @EventStream = Net::Socket();
        IsConnected = false;
        IsLooping = false;
        @Room = null;
        MapList::Visible = false;
    }

    int AddSequenceValue(Json::Value@ val) {
        uint seq = SequenceNext;
        val["seq"] = seq;
        SequenceNext += 1;
        return seq;
    }

    Json::Value@ ExpectReply(uint SequenceCode, uint timeout = 5000) {
        uint64 TimeoutDate = Time::Now + timeout;
        Json::Value@ Message = null;
        while (Time::Now < TimeoutDate && @Message == null) {
            yield();
            for (uint i = 0; i < Received.Length; i++) {
                if (Received[i].Sequence == SequenceCode) {
                    @Message = Received[i].Body;
                    Received.RemoveAt(i);
                    break;       
                }
            }
        }
        return Message;
    }

    Json::Value@ Post(string&in Type, Json::Value@ Body, bool blocking = false, uint timeout = 5000) {
        Body["req"] = Type;
        uint Sequence = AddSequenceValue(Body);
        string Text = Json::Write(Body);
        if (!_protocol.Send(Text)) return null; // TODO: connection fault?
        RequestInProgress = blocking;
        Json::Value@ Reply = ExpectReply(Sequence, timeout);
        RequestInProgress = false;

        if (Reply !is null && Reply.HasKey("error")) {
            trace("Request [" + Type + "]: Error: " + string(Reply["error"]));
            UI::ShowNotification("", Icons::Times + " " + string(Reply["error"]), vec4(.8, 0., 0., 1.), 5000);
            return null;
        }
        return Reply;
    }

    void FireEvent(string&in Type, Json::Value@ Body) {
        Body["event"] = Type;
        string Text = Json::Write(Body);
        if (!_protocol.Send(Text)) return; // TODO: connection fault?
    }

    void CreateRoom() {
        auto Body = Serialize(RoomConfig);

        Json::Value@ Response = Post("CreateRoom", Body, true);
        if (Response is null) {
            trace("Network: CreateRoom - No reply from server.");
            Reset();
            return;
        }

        // The room was created. Setting up room status (local player is host)
        @Room = GameRoom();
        Room.Config = RoomConfig;
        string RoomCode = Response["join_code"];
        Room.MaxTeams = int(Response["max_teams"]);
        Window::RoomCodeVisible = false;

        Room.Teams = {};
        auto JsonTeams = Response["teams"];
        for (uint i = 0; i < JsonTeams.Length; i++) {
            auto JsonTeam = JsonTeams[i];
            Room.Teams.InsertLast(Team(
                JsonTeam["id"], 
                JsonTeam["name"],
                vec3(JsonTeam["color"][0] / 255., JsonTeam["color"][1] / 255., JsonTeam["color"][2] / 255.)
            ));
        }

        Room.Name = Response["name"];
        Room.LocalPlayerIsHost = true;
        Room.HostName = LocalUsername;
        Room.JoinCode = RoomCode;
        @Room.Players = { Player(LocalUsername, Room.Teams[0], true) };
        Room.MapsLoadingStatus = LoadStatus::Loading;
    }

    void CreateTeam() {
        Network::Post("CreateTeam", Json::Object());
    }

    void JoinRoom() {
        auto Body = Json::Object();
        Body["join_code"] = Window::JoinCodeInput;

        auto Response = Post("JoinRoom", Body, true);
        if (Response is null) {
            trace("Network: JoinRoom - No reply from server.");
            Reset();
            return;
        }
        
        if (Response.HasKey("error")) {
            UI::ShowNotification(Icons::Times + string(Response["error"]));  
        } else {
            // Success!
            @Room = GameRoom();
            Room.Name = Response["name"];
            Room.Config = Deserialize(Response["config"]);
            Room.JoinCode = Window::JoinCodeInput;
            Room.LocalPlayerIsHost = false;
            Room.MapsLoadingStatus = LoadStatus::LoadSuccess;
            NetworkHandlers::UpdateRoom(Response["status"]);

            Window::JoinCodeVisible = false;
            Window::RoomCodeVisible = false;
        }
    }

    void EditRoomSettings() {
        auto Body = Json::Object();
        Body["config"] = Serialize(RoomConfig);

        auto Response = Post("EditRoomConfig", Body, true);
        if (Response is null) {
            trace("Network: EditRoomSettings - No reply from server.");
            Reset();
            return;
        }
        
        if (Response.HasKey("error")) {
            UI::ShowNotification(Icons::Times + string(Response["error"]));  
        } else {
            SettingsWindow::Visible = false;
        }
    }

    void LeaveRoom() {
        FireEvent("LeaveRoom", Json::Object());
        Reset();
    }

    void JoinTeam(Team Team) {
        if (Room.GetSelf().Team == Team)
            return;

        auto Body = Json::Object();
        Body["team_id"] = Team.Id;
        FireEvent("ChangeTeam", Body);
    }

    void StartGame() {
        Post("StartGame", Json::Object(), true);
    }

    bool ClaimCell(string&in uid, RunResult result) {
        auto Body = Json::Object();
        Body["uid"] = uid;
        Body["time"] = result.Time;
        Body["medal"] = result.Medal;
        auto Request = Network::Post("ClaimCell", Body, false);
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
        Room.Name = response["room_name"];
        Room.Config = Deserialize(response["config"]);
        Room.JoinCode = response["join_code"];
        Room.LocalPlayerIsHost = response["host"];
        NetworkHandlers::UpdateRoom(response["status"]);
        NetworkHandlers::LoadMaps(response["maps"]);
        if (response.HasKey("game_data")) {
            NetworkHandlers::LoadGameData(response["game_data"]);
            Room.InGame = true;
        }
    }

    void NotifyCountdownEnd() {
        FireEvent("CountdownEnd", Json::Object());
    }
}
