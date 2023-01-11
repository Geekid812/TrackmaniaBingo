
namespace Network {
    const int SECRET_LENGTH = 16;

    // Server TCP socket listening for events
    Net::Socket@ EventStream = Net::Socket();
    // Suspend UI while a blocking request is happening
    bool RequestInProgress = false;
    // Loop running indicator
    bool IsLooping = false;
    // Connection indicator
    bool IsConnected = false;
    // Secret token provided by the server
    string Secret;
    // Secret token used during reconnection sync
    string ReconnectToken;

    Protocol _protocol;
    string AuthToken;
    uint64 TokenExpireDate;
    bool IsOffline;
    uint SequenceNext;
    array<Response@> Received;

    class Response {
        uint Sequence;
        Json::Value@ Body;

        Response(uint seq, Json::Value@ body) {
            Sequence = seq;
            @Body = body;
        }
    }

    void Init() {
        _protocol = Protocol();
        TokenExpireDate = 0;
        IsOffline = false;
        SequenceNext = 0;
        Received = {};
        FetchAuthToken();
        OpenConnection();
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
        handshake.ClientVersion = Meta::ExecutingPlugin().Version;
        if (Time::Now > TokenExpireDate) {
            trace("Network: could not open a connection: authentication token is not valid.");
            return false;
        }
        handshake.AuthToken = AuthToken;
        int code = _protocol.Connect(Settings::BackendURL, Settings::TcpPort, handshake);
        if (code != -1) HandleHandshakeCode(HandshakeCode(code));
        return _protocol.State == ConnectionState::Connected;
    }

    void HandleHandshakeCode(HandshakeCode code) {
        if (code == HandshakeCode::Ok) return;
        if (code == HandshakeCode::IncompatibleVersion) {
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
    }

    bool Connected() {
        return _protocol.State == ConnectionState::Connected;
    }

    void Handle(Json::Value@ Body) {
        if (Body.HasKey("seq")) {
            uint SequenceCode = Body["seq"];
            Response@ res = Response(SequenceCode, Body);
            Received.InsertLast(res);
            yield();
            return;
        }
        if (@Room == null) return;
        if (Body["event"] == "RoomUpdate") {
            NetworkHandlers::UpdateRoom(Body);
        } else if (Body["event"] == "RoomConfigUpdate") {
            Room.Config = Deserialize(Body);
        } else if (Body["event"] == "MapsLoadResult") {
            Room.MapsLoadingStatus = bool(Body["loaded"]) ? LoadStatus::LoadSuccess : LoadStatus::LoadFail;
        } else if (Body["method"] == "GAME_START") {
            @Room.MapList = {};
            if (Body["maplist"].Length < 25) return; // Prevents a crash, user needs to retry later
            for (uint i = 0; i < Body["maplist"].Length; i++) {
                auto JsonMap = Body["maplist"][i];
                Room.MapList.InsertLast(Map(
                    JsonMap["name"],
                    JsonMap["author"],
                    JsonMap["tmxid"],
                    JsonMap["uid"]
                ));
            }

            StartCountdown = Settings::DevMode ? 1000 : 5000;
        } else if (Body["method"] == "CLAIM_CELL") {
            Map@ ClaimedMap = Room.MapList[Body["cellid"]];
            RunResult Result = RunResult(int(Body["time"]), Medal(int(Body["medal"])));
            Team team = Room.GetTeamWithId(int(Body["team_id"]));
            @ClaimedMap.ClaimedTeam = @team;
            ClaimedMap.ClaimedRun = Result;

            string PlayerName = Body["playername"];
            string MapName = Body["mapname"];
            string TeamName = team.Name;
            bool IsReclaim = Body["delta"] != -1;
            bool IsImprovement = Body["improve"];
            string DeltaFormatted = "-" + Time::Format(Body["delta"]);
            vec4 TeamColor = UIColor::Brighten(UIColor::GetAlphaColor(team.Color, 0.1), 0.75);
            vec4 DimColor = TeamColor / 1.5;
            
            if (!IsReclaim) {
                UI::ShowNotification(Icons::Bookmark + " Map Claimed", PlayerName + " has claimed \\$fd8" + MapName + "\\$z for " + TeamName + " Team\n" + Result.Display(), TeamColor, 15000);
            } else if (IsImprovement) {
                UI::ShowNotification(Icons::ClockO + " Time Improved", PlayerName + " has improved " + TeamName + " Team's time on \\$fd8" + MapName + "\\$z\n" + Result.Display() + " (" + DeltaFormatted + ")", DimColor, 15000);
            } else { // Reclaim
                UI::ShowNotification(Icons::Retweet + " Map Reclaimed", PlayerName + " has reclaimed \\$fd8" + MapName + "\\$z for " + TeamName + " Team\n" + Result.Display() + " (" + DeltaFormatted + ")", TeamColor, 15000);
            }
                
        } else if (Body["method"] == "GAME_END") {
            Team team = Room.GetTeamWithId(int(Body["team_id"]));
            string TeamName = "\\$" + UIColor::GetHex(team.Color) + team.Name;
            UI::ShowNotification(Icons::Trophy + " Bingo!", TeamName + "\\$z has won the game!", vec4(.6, .6, 0, 1), 20000);

            Room.EndState.BingoDirection = BingoDirection(int(Body["bingodir"]));
            Room.EndState.Offset = Body["offset"];
            Room.EndState.EndTime = Time::Now;
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

    void OnDisconnect() {
        Reset();

        // Not a clean disconnect
        UI::ShowNotification(Icons::ExclamationCircle + " You have been disconnected! Attempting to reconnect...");
        print("Disconnected! Client is attemping reconnection...");
        yield(); // Wait for old loop cleanup

        int RetryBackoff = 5000;
        uint RetryAttempts = 1;
        bool ReconnectSuccess = false; 
        while (RetryAttempts <= 5 && !ReconnectSuccess) {
            if (TryConnect()) {
                trace("Syncing with server...");
                if (true) {
                    UI::ShowNotification("", Icons::Check + " Reconnected!", vec4(.2, .2, .9, 1));
                    print("Reconnection succeeded!");
                    ReconnectSuccess = true;
                    break;
                } else {
                    trace("Syncing did not succeed.");
                }
            }

            // Reconnect failure
            string ReconnectionInfo;
            if (RetryAttempts == 5) {
                ReconnectionInfo = "Reconnection failed " + RetryAttempts + " time(s).";
                RetryBackoff = 5000;
            } else {
                ReconnectionInfo = "Reconnection failed " + RetryAttempts + " time(s). Retrying in " + (RetryBackoff / 1000) + " seconds.";
            }
            trace(ReconnectionInfo);
            UI::ShowNotification(Icons::ExclamationCircle + " " + ReconnectionInfo, RetryBackoff - 500);
            if (RetryAttempts == 5) break;

            RequestInProgress = true;
            sleep(RetryBackoff);
            RetryAttempts += 1;
            RetryBackoff += 5000;
            UI::ShowNotification(Icons::ExclamationCircle + " Attempting to reconnect...", Math::Min(Settings::ConnectionTimeout - 500, 10000));
        }

        if (!ReconnectSuccess) {
            UI::ShowNotification("", Icons::Times + " Reconnection has failed!", vec4(.6, .1, .1, 1), 10000);
            warn("Reconnection has failed!");
        }
    }

    void Reset() {
        EventStream.Close();
        @EventStream = Net::Socket();
        IsConnected = false;
        IsLooping = false;
        @Room = null;
        MapList::Visible = false;
        ReconnectToken = Secret;
    }

    bool TryConnect() {
        RequestInProgress = true;
        if (!IsLooping) {
            IsLooping = true;
            startnew(Network::Loop);
            while (!IsConnected && IsLooping) yield();
        }

        RequestInProgress = false;
        return IsConnected;
    }

    Net::HttpRequest@ PostRequest(string&in Url, string&in Body, bool Blocking) {
        auto Request = Net::HttpPost(Url, Body);
        Request.Start();
        if (Blocking) RequestInProgress = true;
        while (!Request.Finished()) { yield(); }
        if (Blocking) RequestInProgress = false;

        int Status = Request.ResponseCode();
        if (Status == 0) {
            trace(Url + " request failed");
            UI::ShowNotification(Icons::Times + " Connection Failed", "The server could not be reached. Please check your connection. \n" + Request.Error(), vec4(.6, 0, 0, 1));
            return null;
        } else if (Status / 100 != 2) { // Not a 2XX status code
            trace(Url + " received status code " + Status);
            if (Status == 426) { // Upgrade required
            } else { // Default case
                UI::ShowNotification(Icons::Times + " Connection Error", "An error occured while communicating with the server. (Error " + Status + ")", vec4(.6, 0, 0, 1));  
            }
            return null; 
        }

        return Request;
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
        Body["request"] = Type;
        uint Sequence = AddSequenceValue(Body);
        string Text = Json::Write(Body);
        if (!_protocol.Send(Text)) return null; // TODO: connection fault?
        RequestInProgress = blocking;
        Json::Value@ Reply = ExpectReply(Sequence, timeout);
        RequestInProgress = false;
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
            Room.Config = RoomConfig;
            SettingsWindow::Visible = false;
        }
    }

    void LeaveRoom(){
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
        auto Body = Json::Object();
        Body["client_secret"] = Secret;
        Network::PostRequest("http://" + Settings::BackendURL + ":" + Settings::HttpPort + "/start", Json::Write(Body), true);
    }

    bool ClaimCell(string&in uid, RunResult result) {
        auto Body = Json::Object();
        Body["uid"] = uid;
        Body["time"] = result.Time;
        Body["medal"] = result.Medal;
        Body["client_secret"] = Secret;
        auto Request = Network::PostRequest("http://" + Settings::BackendURL + ":" + Settings::HttpPort + "/claim", Json::Write(Body), false);
        return @Request != null;
    }

    // Network identifier
    string GetLogin() {
        auto Network = cast<CTrackManiaNetwork>(GetApp().Network);
        return Network.PlayerInfo.Login;
    }
}
