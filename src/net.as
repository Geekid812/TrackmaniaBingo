
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
        while (EventStream.Available() == 0) { yield(); }
        string InitialResponse = EventStream.ReadRaw(EventStream.Available());
        if (InitialResponse.Length < SECRET_LENGTH) {
            IsLooping = false;
            return;
        }
        // OK
        IsConnected = true;
        Secret = InitialResponse.SubStr(0, SECRET_LENGTH);
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

            StartCountdown = 5000;
        } else if (Body["method"] == "CLAIM_CELL") {
            Map@ ClaimedMap = Room.MapList[Body["cellid"]];
            RunResult Result = RunResult(int(Body["time"]), Medal(int(Body["medal"])));
            ClaimedMap.ClaimedTeam = Body["team"];
            ClaimedMap.ClaimedRun = Result;

            string PlayerName = Body["playername"];
            string MapName = Body["mapname"];
            string TeamName = (Body["team"] == 0 ? "Red" : "Blue");
            bool IsReclaim = Body["delta"] != -1;
            bool IsImprovement = Body["improve"];
            string DeltaFormatted = "-" + Time::Format(Body["delta"]);
            vec4 TeamColor = (Body["team"] == 0 ? vec4(.6, .2, .2, 1.) : vec4(.2, .2, .6, 1.));
            vec4 DimColor = TeamColor / 1.5;
            
            if (!IsReclaim) {
                UI::ShowNotification(Icons::Bookmark + " Map Claimed", PlayerName + " has claimed \\$fd8" + MapName + "\\$z for " + TeamName + " Team\n" + Result.Display(), TeamColor, 15000);
            } else if (IsImprovement) {
                UI::ShowNotification(Icons::ClockO + " Time Improved", PlayerName + " has improved " + TeamName + " Team's time on \\$fd8" + MapName + "\\$z\n" + Result.Display() + " (" + DeltaFormatted + ")", DimColor, 15000);
            } else { // Reclaim
                UI::ShowNotification(Icons::Retweet + " Map Reclaimed", PlayerName + " has reclaimed \\$fd8" + MapName + "\\$z for " + TeamName + " Team\n" + Result.Display() + " (" + DeltaFormatted + ")", TeamColor, 15000);
            }
                
        } else if (Body["method"] == "GAME_END") {
            string TeamName = (Body["winner"] == 0 ? "\\$e33Red Team" : "\\$33eBlue Team");
            UI::ShowNotification(Icons::Trophy + " Bingo!", TeamName + "\\$z has won the game!", vec4(.6, .6, 0, 1), 20000);

            Room.EndState.BingoDirection = BingoDirection(int(Body["bingodir"]));
            Room.EndState.Offset = Body["offset"];
            Room.EndState.EndTime = Time::Now;
        } else if (Body["method"] == "MAPS_LOAD_STATUS") {
            Room.MapsLoadingStatus = LoadStatus(int(Body["status"]));
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
        Room.EndState = EndState();
        Room.MapsLoadingStatus = LoadStatus::Loading;
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

        int Status = Request.ResponseCode();
        if (Status == 0) {
            UI::ShowNotification(Icons::Times + " Connection Failed", "The server could not be reached. Please check your connection. \n" + Request.Error(), vec4(.6, 0, 0, 1));
            return null;
        } else if (Status / 100 != 2) { // Not a 2XX status code
            if (Status == 426) { // Upgrade required
                UI::ShowNotification(Icons::ArrowCircleOUp + " Update required!", "Please update the Bingo plugin to continue playing.", vec4(.2, .2, .9, 1));
            } else { // Default case
                UI::ShowNotification(Icons::Times + " Connection Error", "An error occured while communicating with the server. (Error " + Status + ")", vec4(.6, 0, 0, 1));  
            }
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
        Body["client_secret"] = Secret;
        Body["version"] = Meta::ExecutingPlugin().Version;

        auto Request = PostRequest(Settings::BackendURL + ":" + Settings::HttpPort + "/create", Json::Write(Body), true);
        if (Request is null) {
            Reset();
            return;
        }

        string json = Request.String();
        auto response = Json::Parse(json);
        string RoomCode = response["room_code"];

        Room.Active = true;
        Room.LocalPlayerIsHost = true;
        Room.HostName = LocalUsername;
        Room.JoinCode = RoomCode;
        @Room.Players = { Player(LocalUsername, 0, true) };
        Room.MapsLoadingStatus = LoadStatus::Loading;
    }

    void JoinRoom() {
        if (!TryConnect()) return;

        string LocalUsername = cast<CTrackManiaNetwork@>(GetApp().Network).PlayerInfo.Name;
        auto Body = Json::Object();
        Body["name"] = LocalUsername;
        Body["code"] = Room.JoinCode;
        Body["client_secret"] = Secret;
        Body["version"] = Meta::ExecutingPlugin().Version;

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

            Room.LocalPlayerIsHost = false;
            Room.MaxPlayers = JsonRoom["size"];
            Room.MapSelection = MapMode(int(JsonRoom["selection"]));
            Room.TargetMedal = Medal(int(JsonRoom["medal"]));
            Room.HostName = JsonRoom["host"];
            Room.MapsLoadingStatus = LoadStatus(int(JsonRoom["status"]));

            Room.Active = true;
            ShouldClose = false;
        }
        if (ShouldClose) Network::Reset();
    }

    void JoinTeam(int Team) {
        if (Room.GetSelf().Team == Team)
            return;

        auto Body = Json::Object();
        Body["team"] = Team;
        Body["client_secret"] = Secret;
        Network::PostRequest("http://" + Settings::BackendURL + ":" + Settings::HttpPort + "/team-update", Json::Write(Body), false);
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
