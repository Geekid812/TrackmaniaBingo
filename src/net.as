
namespace Network {
    // Server TCP socket listening for events
    Net::Socket@ EventStream = Net::Socket();
    // Suspend UI while a blocking request is happening
    bool RequestInProgress = false;
    // Loop running indicator
    bool IsLooping = false;
    // Connection indicator
    bool IsConnected = false;

    void Loop() {
        trace("Connecting to "+ Settings::BackendURL + ":" + Settings::TcpPort);
        if (!EventStream.Connect(Settings::BackendURL, Settings::TcpPort)) {
            trace("Failed to open TCP connection.");
            IsLooping = false;
            return;
        }
        // Sleep a bit because for some reason the server takes
        // time to register the TCP connection (gotta love proxies)
        sleep(100);
        
        // Identification
        EventStream.WriteRaw(GetLogin() + "\n");
        while (EventStream.Available() == 0) { yield(); }
        if (EventStream.ReadRaw(EventStream.Available()) != "OK\u0004") {
            IsLooping = false;
            return;
        }
        // OK
        IsConnected = true;
        trace("Connection established. Remote IP: " + EventStream.GetRemoteIP());
        while (true) {
            while (EventStream.Available() == 0) {
                if (!IsLooping) break; // Manual disconnect
                if (EventStream.CanRead()) {
                    // Client is disconnected
                    OnDisconnect();
                    break;
                }
                yield();
            }
            if (EventStream.Available() == 0) break; // Close loop if disconnected
            string Message = EventStream.ReadRaw(EventStream.Available());
            trace("Received: " + Message);
            string[]@ Events = Message.Split("\u0004"); // Control character to seperate messages
            for (uint i = 0; i < Events.Length - 1; i++) {
                if (Events[i] == "PING") continue; // Just a simple ping
                Handle(Json::Parse(Events[i]));
            }
        }

        IsLooping = false;
        IsConnected = false;
    }

    void Handle(Json::Value@ Body) {
        if (Body["method"] == "ROOM_UPDATE") {
            string LocalUsername = cast<CTrackManiaNetwork@>(GetApp().Network).PlayerInfo.Name;
            @Room.Players = {};
            for (uint i = 0; i < Body["members"].Length; i++) {
                auto JsonPlayer = Body["members"][i];
                Room.Players.InsertLast(Player(
                    JsonPlayer["name"],
                    JsonPlayer["team"],
                    JsonPlayer["name"] == LocalUsername
                ));
            }
        } else if (Body["method"] == "GAME_START") {
            @Room.MapList = {};
            for (uint i = 0; i < Body["maplist"].Length; i++) {
                auto JsonMap = Body["maplist"][i];
                Room.MapList.InsertLast(Map(
                    JsonMap["name"],
                    JsonMap["author"],
                    JsonMap["tmxid"],
                    JsonMap["uid"]
                ));
            }

            StartCountdown = 5000;
        } else if (Body["method"] == "CLAIM_CELL") {
            auto ClaimedMap = Room.MapList[Body["cellid"]];
            ClaimedMap.ClaimedTeam = Body["team"];
            string PlayerName = Body["playername"];
            string MapName = Body["mapname"];
            string TeamName = (Body["team"] == 0 ? "Red" : "Blue");
            vec4 TeamColor = (Body["team"] == 0 ? vec4(.6, .2, .2, 1.) : vec4(.2, .2, .6, 1.));
            UI::ShowNotification(Icons::Bookmark + " Map Claimed", PlayerName + " has claimed \\$fd8" + MapName + "\\$z for " + TeamName + " Team", TeamColor, 12000);
        } else if (Body["method"] == "GAME_END") {
            string TeamName = (Body["winner"] == 0 ? "\\$e33Red Team" : "\\$33eBlue Team");
            UI::ShowNotification(Icons::Trophy + " Bingo!", TeamName + "\\$z has won the game!", vec4(.8, .8, 0, 1), 12000);

            Room.EndState.BingoDirection = BingoDirection(int(Body["bingodir"]));
            Room.EndState.Offset = Body["offset"];
            Room.EndState.EndTime = Time::Now;
        }
    }

    void OnDisconnect() {
        Reset();
        print("Disconnected! Connection status has been reset.");
    }

    void Reset() {
        EventStream.Close();
        @EventStream = Net::Socket();
        IsConnected = false;
        IsLooping = false;
        Room.Active = false;
        Room.InGame = false;
        MapList::Visible = false;
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

        if (Request.ResponseCode() == 0) {
            UI::ShowNotification(Icons::Times + "Connection Failed", "The server could not be reached. Please check your connection. \n" + Request.Error(), vec4(.6, 0, 0, 1));
            return null;
        } else if (Request.ResponseCode() / 100 != 2) { // 2XX status code
            UI::ShowNotification(Icons::Times + "Connection Error", "An error occured while communicating with the server. (Error " + Request.ResponseCode() + ")", vec4(.6, 0, 0, 1));  
            return null; 
        }

        return Request;
    }

    void CreateRoom() {
        if (!TryConnect()) return;

        string LocalUsername = cast<CTrackManiaNetwork@>(GetApp().Network).PlayerInfo.Name;
        auto Body = Json::Object();
        Body["size"] = Room.MaxPlayers;
        Body["selection"] = Room.MapSelection;
        Body["medal"] = Room.TargetMedal;
        Body["name"] = LocalUsername;
        Body["login"] = GetLogin();

        auto Request = Network::PostRequest(Settings::BackendURL + ":" + Settings::HttpPort + "/create", Json::Write(Body), true);
        if (Request is null) {
            Reset();
            return;
        }

        string RoomCode = Request.String();
        Room.Active = true;
        Room.LocalPlayerIsHost = true;
        Room.HostName = LocalUsername;
        Room.JoinCode = RoomCode;
        @Room.Players = { Player(LocalUsername, 0, true) };
    }

    void JoinRoom() {
        if (!TryConnect()) return;

        string LocalUsername = cast<CTrackManiaNetwork@>(GetApp().Network).PlayerInfo.Name;
        auto Body = Json::Object();
        Body["name"] = LocalUsername;
        Body["code"] = Room.JoinCode;
        Body["login"] = GetLogin();

        auto Request = Network::PostRequest(Settings::BackendURL + ":" + Settings::HttpPort + "/join", Json::Write(Body), true);
        if (Request is null) {
            Reset();
            return;
        }

        bool ShouldClose = true;
        if (Request.ResponseCode() == 204) {
            UI::ShowNotification(Icons::Times + " No room was found with code " + Room.JoinCode + ".");  
        } else if (Request.ResponseCode() == 298) {
            UI::ShowNotification(Icons::Times + " Sorry, this room is already full.");
        } else if (Request.ResponseCode() == 299) {
            UI::ShowNotification(Icons::Times + " Sorry, the game has already started in this room.");  
        } else {
            // Success!
            auto JsonRoom = Json::Parse(Request.String());

            Room.MaxPlayers = JsonRoom["size"];
            Room.MapSelection = MapMode(int(JsonRoom["selection"]));
            Room.TargetMedal = Medal(int(JsonRoom["medal"]));
            Room.HostName = JsonRoom["host"];

            Room.Active = true;
            ShouldClose = false;
        }
        if (ShouldClose) Network::Reset();
    }

    void JoinTeam(int Team) {
        auto Body = Json::Object();
        Body["team"] = Team;
        Body["login"] = GetLogin();
        Network::PostRequest("http://" + Settings::BackendURL + ":" + Settings::HttpPort + "/team-update", Json::Write(Body), false);
    }

    void StartGame() {
        Network::PostRequest("http://" + Settings::BackendURL + ":" + Settings::HttpPort + "/start", GetLogin(), true);
    }

    void ClaimCell(string&in uid) {
        auto Body = Json::Object();
        Body["uid"] = uid;
        Body["login"] = GetLogin();
        Network::PostRequest("http://" + Settings::BackendURL + ":" + Settings::HttpPort + "/claim", Json::Write(Body), false);
    }

    // Network identifier
    string GetLogin() {
        auto Network = cast<CTrackManiaNetwork>(GetApp().Network);
        return Network.PlayerInfo.Login;
    }
}