
namespace Network {
    const int SECRET_LENGTH = 32;

    namespace Internal {
        // Disable UI interactions while a blocking request is happening
        bool SuspendUI = false;
        // Connection indicator
        bool ConnectionOpen = false;
        // Offline mode indicator
        bool OfflineMode = false;
        // Sequence counter
        uint SequenceNext = 0;
        // Temporary buffer of server request messages
        array<Response @> Received = {};
        // Recent error messages
        dictionary Errors = {};
        // Currently attempting to reconnect to a match
        bool Reconnecting = false;
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
        Json::Value @body;

        Response(uint seq, Json::Value @body) {
            this.sequence = seq;
            @ this.body = body;
        }

    }

    void
    Reset() {

        _protocol = Protocol();
        Internal::SuspendUI = false;
        Internal::ConnectionOpen = false;
        Internal::OfflineMode = false;
        Internal::SequenceNext = 0;
        Internal::Received = {};
        Internal::Errors = {};
        Timings::LastPingSent = 0;
        Timings::LastPingReceived = 0;
    }

    void Connect() {
        SetOfflineMode(false);

        Timings::LastPingSent = Time::Now;
        Timings::LastPingReceived = Time::Now;
        OpenConnection();
        Internal::ConnectionOpen = IsConnected();
        SetOfflineMode(!Internal::ConnectionOpen);
    }

    bool IsOfflineMode() { return Internal::OfflineMode; }

    void SetOfflineMode(bool offline) { Internal::OfflineMode = offline; }

    bool IsConnected() { return _protocol.state == ConnectionState::Connected; }

    ConnectionState GetState() { return _protocol.state; }

    bool IsUISuspended() { return Internal::SuspendUI; }

    void OpenConnection() {
        int retries = 3;
        while (!IsConnected() && retries > 0) {
            auto handshake = HandshakeRequest();
            handshake.version = Meta::ExecutingPlugin().Version;
            handshake.token = PersistantStorage::ClientToken;
            handshake.game = CURRENT_GAME;

            Settings::BackendConfiguration @backend = Settings::GetBackendConfiguration();
            int code = _protocol.Connect(backend.NetworkAddress, backend.TcpPort, handshake);

            // If the handshake code was not handled, this is the last retry.
            if (code == -2)
                retries = 1;

            if (!IsConnected()) {
                retries -= 1;
                logwarn("[Network] Failed to connect. " + retries + " retry attempts left.");
            }
        }
    }

    void Loop() {
        if (!IsConnected()) {
            if (Internal::ConnectionOpen)
                OnDisconnect();
            return;
        }

        if (!ShouldStayConnected()) {
            loginfo("[Network] Plugin not active, disconnecting from the server.");
            CloseConnection();
            return;
        }

        string message = _protocol.Recv();
        while (message != "") {
            logtrace("[Network] <- " + message);
            Json::Value json;
            try {
                json = Json::Parse(message);
            } catch {
                logwarn("[Network] Failed to parse received message. Got: " + message);
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

        if (Timings::LastPingReceived + Settings::PingInterval + Settings::NetworkTimeout <=
            Time::Now) {
            OnDisconnect();
        }
    }

    bool ShouldStayConnected() {
        return UIMainWindow::Visible || @Match != null ||
               PersistantStorage::SubscribeToRoomUpdates ||
               PersistantStorage::LastConnectedMatchId != "";
    }

    void DoPing() {
        if (@Post("Ping", Json::Object(), false) != null) {
            Timings::LastPingReceived = Time::Now;
        }
    }

    void OnDisconnect() {
        logtrace("[Network] Disconnected! Attempting to reconnect...");
        Reset();
        Connect();
        if (!IsConnected()) {
            Gamemaster::Shutdown();
            UI::ShowNotification(Icons::Exclamation + " Bingo: You have been disconnected!",
                                 "Use the plugin interface to reconnect.",
                                 vec4(.9, .1, .1, 1.),
                                 10000);
            Internal::OfflineMode = true;
        } else {
            logtrace("[Network] Reconnected to server.");
        }
    }

    void TestConnection() {
        uint64 start = Time::Now;
        auto response = Post("Ping", Json::Object(), false);
        uint64 end = Time::Now - start;
        bool result = response !is null;
        logtrace("[Network::TestConnection] " + tostring(result) + " in " + end + "ms");
    }

    void Handle(Json::Value @body) {
        if (body.HasKey("seq")) {
            uint SequenceCode = body["seq"];
            Response @res = Response(SequenceCode, body);
            Internal::Received.InsertLast(res);
            yield();
            return;
        }
        if (!body.HasKey("event")) {
            logwarn("Invalid message, discarding.");
            return;
        }
        string event = body["event"];
        if (event == "PlayerUpdate") {
            NetworkHandlers::PlayerUpdate(body);
        } else if (event == "MatchStart") {
            NetworkHandlers::MatchStart(body);
        } else if (event == "RunSubmitted") {
            NetworkHandlers::RunSubmitted(body);
        } else if (event == "ConfigUpdate") {
            NetworkHandlers::UpdateConfig(body);
        } else if (event == "RoomListed") {
            NetworkHandlers::AddRoomListing(body);
        } else if (event == "RoomUnlisted") {
            NetworkHandlers::RemoveRoomListing(body);
        } else if (event == "RoomlistPlayerCountUpdate") {
            NetworkHandlers::RoomlistPlayerUpdate(body);
        } else if (event == "RoomlistConfigUpdate") {
            NetworkHandlers::RoomlistUpdateConfig(body);
        } else if (event == "RoomlistInGameStatusUpdate") {
            NetworkHandlers::RoomlistInGameStatusUpdate(body);
        } else if (event == "PlayerJoin") {
            NetworkHandlers::PlayerJoin(body);
        } else if (event == "PlayerLeave") {
            NetworkHandlers::PlayerLeave(body);
        } else if (event == "AnnounceBingo") {
            NetworkHandlers::AnnounceBingo(body);
        } else if (event == "TeamCreated") {
            NetworkHandlers::TeamCreated(body);
        } else if (event == "TeamDeleted") {
            NetworkHandlers::TeamDeleted(body);
        } else if (event == "PhaseChange") {
            NetworkHandlers::PhaseChange(body);
        } else if (event == "RoomSync") {
            NetworkHandlers::RoomSync(body);
        } else if (event == "MatchSync") {
            NetworkHandlers::MatchSync(body);
        } else if (event == "AnnounceWinByCellCount") {
            NetworkHandlers::AnnounceWinByCellCount(body);
        } else if (event == "AnnounceDraw") {
            NetworkHandlers::AnnounceDraw(body);
        } else if (event == "MatchTeamCreated") {
            NetworkHandlers::MatchTeamCreated(body);
        } else if (event == "MatchPlayerJoin") {
            NetworkHandlers::MatchPlayerJoin(body);
        } else if (event == "MapRerolled") {
            NetworkHandlers::MapRerolled(body);
        } else if (event == "ChatMessage") {
            NetworkHandlers::ChatMessage(body);
        } else if (event == "PollStart") {
            NetworkHandlers::PollStart(body);
        } else if (event == "PollVotesUpdate") {
            NetworkHandlers::PollVotesUpdate(body);
        } else if (event == "PollResult") {
            NetworkHandlers::PollResult(body);
        } else if (event == "PowerupSpawn") {
            NetworkHandlers::PowerupSpawn(body);
        } else if (event == "PowerupActivated") {
            NetworkHandlers::PowerupActivated(body);
        } else if (event == "ItemSlotEquip") {
            NetworkHandlers::ItemSlotEquip(body);
        } else if (event == "RallyResolved") {
            NetworkHandlers::RallyResolved(body);
        } else if (event == "JailResolved") {
            NetworkHandlers::JailResolved(body);
        } else if (event == "StartPlayVerification") {
            NetworkHandlers::StartPlayVerification(body);
        } else {
            logwarn("[Network] Unknown event: " + string(body["event"]));
        }
    }

    void CloseConnection() {
        Reset();
        logtrace("[Network::CloseConnection] Connection closed.");
    }

    int AddSequenceValue(Json::Value @val) {
        uint seq = Internal::SequenceNext;
        val["seq"] = seq;
        Internal::SequenceNext += 1;
        return seq;
    }

    Json::Value @ExpectReply(uint SequenceCode, uint timeout = 5000) {
        uint64 timeoutDate = Time::Now + timeout;
        Json::Value @message = null;
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

    Json::Value
        @Post(string& in type, Json::Value @body, bool blocking = false, uint timeout = 5000) {
        body["req"] = type;
        uint Sequence = AddSequenceValue(body);
        string Text = Json::Write(body);
        logtrace("[Network] -> " + Text);
        if (!_protocol.Send(Text)) {
            logwarn("[Network] Post preemptively failed!");
            if (Network::IsConnected())
                OnDisconnect();
            return null;
        }

        Internal::Errors.Delete(type);
        Internal::SuspendUI = blocking;
        Json::Value @reply = ExpectReply(Sequence, timeout);
        if (blocking)
            Internal::SuspendUI = false;

        if (reply !is null && reply.HasKey("error")) {
            string err = string(reply["error"]);
            logtrace("[Network::Post] Request [" + type + "]: Error: " + err);
            UI::ShowNotification(
                "", Icons::Times + " Error in " + type + ": " + err, vec4(.8, 0., 0., 1.), 10000);
            Internal::Errors[type] = err;
            return null;
        }
        if (reply is null)
            Internal::Errors[type] = "timeout";
        return reply;
    }

    string GetError(string& in type) {
        string err = "";
        Internal::Errors.Get(type, err);
        return err;
    }

    void CreateRoom() {
        MatchConfig.game = CURRENT_GAME;

        if (TeamPresets.Length < 2) {
            PersistantStorage::LoadTeamEditor();
        }

        auto body = Json::Object();
        body["config"] = RoomConfiguration::Serialize(RoomConfig);
        body["match_config"] = MatchConfiguration::Serialize(MatchConfig);

        auto teams = Json::Array();
        for (uint i = 0; i < TeamPresets.Length; i++) {
            teams.Add(Team::Serialize(TeamPresets[i]));
        }
        body["teams"] = teams;

        Json::Value @response = Post("CreateRoom", body, true);
        if (response is null) {
            logtrace("[Network] CreateRoom - No reply from server.");
            return;
        }

        // The room was created. Setting up room status (local player is host)
        @Match = GameServer();
        Match.roomConfig = RoomConfig;
        Match.config = MatchConfig;
        string roomCode = response["join_code"];
        UIRoomMenu::JoinCodeVisible = false;
        UIRoomMenu::SwitchToContext();

        Match.teams = {};
        auto jsonTeams = response["teams"];
        for (uint i = 0; i < jsonTeams.Length; i++) {
            auto JsonTeam = jsonTeams[i];
            Match.teams.InsertLast(Team(JsonTeam["id"],
                                       JsonTeam["name"],
                                       vec3(JsonTeam["color"][0] / 255.,
                                            JsonTeam["color"][1] / 255.,
                                            JsonTeam["color"][2] / 255.)));
        }

        Match.isLocalPlayerHost = true;
        Match.joinCode = roomCode;
        @Match.players = {Player(Profile, Match.teams[0])};
    }

    void CreateTeam() {
        auto body = Json::Object();
        body["team"] = Team::Serialize(NetParams::TeamCreatePreset);
        Network::Post("CreateTeam", body);
    }

    void DeleteTeam() {
        auto body = Json::Object();
        body["id"] = NetParams::DeletedTeamId;
        Network::Post("DeleteTeam", body);
    }

    void JoinRoom() {
        auto body = Json::Object();
        body["join_code"] = NetParams::JoinCode;

        auto response = Post("JoinRoom", body, true);
        if (response is null) {
            logtrace("[Network] JoinRoom - No reply from server.");
            return;
        }

        @Match = GameServer();
        Match.roomConfig = RoomConfiguration::Deserialize(response["config"]);
        Match.config = MatchConfiguration::Deserialize(response["match_config"]);
        Match.joinCode = NetParams::JoinCode;
        Match.isLocalPlayerHost = (response.HasKey("is_host") ? bool(response["is_host"]) : false);
        NetworkHandlers::LoadRoomTeams(response["teams"]);

        UIRoomMenu::JoinCodeVisible = false;

        // Don't process join handlers if we are reconnecting
        if (Internal::Reconnecting)
            return;

        if (response["match_uid"].GetType() != Json::Type::Null) {
            // We're joining an active game
            string currentMatchUid = response["match_uid"];
            NetParams::MatchJoinUid = currentMatchUid;

            if (canPlayersChooseTheirOwnTeam(Match.roomConfig)) {
                // We have to choose a team before joining
                UITeams::SwitchToJoinContext();
            } else {
                // Cannot choose a team, immediately try to join the match
                NetParams::MatchJoinTeamId = -1;
                Network::JoinMatch();
            }
        } else {
            // We're joining a room without an active game
            UIRoomMenu::SwitchToContext();
        }
    }

    void JoinMatch() {
        auto body = Json::Object();
        body["uid"] = NetParams::MatchJoinUid;
        if (NetParams::MatchJoinTeamId != -1) {
            body["team_id"] = NetParams::MatchJoinTeamId;
        }

        auto response = Post("JoinMatch", body, true);
        if (response is null) {
            logtrace("[Network] JoinMatch - No reply from server.");
            return;
        }

        GameServer @joinedMatch = LiveMatch::Deserialize(response["state"]);

        Gamemaster::SetBingoActive(true);
        UITeams::CloseContext();
        UIChat::ClearHistory();
        @Match = joinedMatch;

        Gamemaster::InitializeTiles();
        Powerups::SyncPowerupEffects();
        UIGameRoom::SwitchToPlayContext();
        PersistantStorage::SaveConnectedMatch();
    }

    void GetPublicRooms() {
        auto response = Post("GetPublicRooms", Json::Object(), false);
        if (response is null) {
            logtrace("[Network] GetPublicRooms - No reply from server.");
            UIRoomMenu::RoomsLoad = LoadStatus::Error;
            return;
        }

        auto rooms = array<NetworkRoom>();
        for (uint i = 0; i < response["rooms"].Length; i++) {
            rooms.InsertLast(NetworkRoom::Deserialize(response["rooms"][i]));
        }
        UIRoomMenu::PublicRooms = rooms;
        UIRoomMenu::RoomsLoad = LoadStatus::Ok;
    }

    void UnsubscribeRoomlist() { Post("UnsubscribeRoomlist", Json::Object(), false); }

    void EditConfig() {
        auto body = Json::Object();
        body["config"] = RoomConfiguration::Serialize(RoomConfig);
        body["match_config"] = MatchConfiguration::Serialize(MatchConfig);

        auto response = Post("EditConfig", body, true);
        if (response is null) {
            logtrace("[Network] EditConfig - No reply from server.");
            return;
        }
        UIEditSettings::Visible = false;
        UIItemSettings::Visible = false;
    }

    void JoinTeam(Team team) {
        if (Match.GetSelf().team == team)
            return;

        auto body = Json::Object();
        body["team_id"] = team.id;
        startnew(function(ref @body) { Post("ChangeTeam", cast<Json::Value @>(body)); }, body);
    }

    void StartMatch() { Post("StartMatch", Json::Object(), true); }

    bool ClaimCell(int tileIndex, CampaignMap campaign, RunResult result) {
        auto body = Json::Object();
        body["tile_index"] = tileIndex;
        body["time"] = result.time;
        body["medal"] = result.medal;
        body["splits"] = Json::Array();

        for (uint i = 0; i < result.checkpoints.Length; i++) {
            body["splits"].Add(result.checkpoints[i]);
        }

        if (campaign.campaignId != -1)
            body["campaign"] = CampaignMap::Serialize(campaign);
        auto Request = Network::Post("SubmitRun", body, false);
        return Request !is null;
    }

    void RerollCell() {
        auto body = Json::Object();
        body["cell_id"] = NetParams::RerollCellId;
        Network::Post("CastRerollVote", body, true);
    }

    void ShuffleTeams() { Network::Post("ShuffleTeams", Json::Object(), true); }

    void SendChatMessage() {
        auto body = Json::Object();
        body["message"] = NetParams::ChatMessage;
        Network::Post("SendChatMessage", body, false);
    }

    void ReloadMaps() { Network::Post("ReloadMaps", Json::Object(), false); }

    void Reconnect() {
        Internal::Reconnecting = true;
        UI::ShowNotification(Icons::Globe + " Reconnecting to your Bingo match...");
        JoinRoom();
        JoinMatch();

        if (!Gamemaster::IsBingoActive() || Match.uid != PersistantStorage::LastConnectedMatchId) {
            logtrace("[Network] Reconnection failure, forgetting previous game save.");
            PersistantStorage::ResetConnectedMatch();
        }
        Internal::Reconnecting = false;
    }

    void PingCell() {
        auto body = Json::Object();
        body["cell_id"] = NetParams::PingCellId;
        Network::Post("PingCell", body, false);
    }

    void SubmitPollVote() {
        auto body = Json::Object();
        body["poll_id"] = NetParams::PollId;
        body["choice"] = NetParams::PollChoiceIndex;
        Network::Post("SubmitPollVote", body, false);
    }

    void ChangePlayerTeam() {
        auto body = Json::Object();
        body["player_uid"] = NetParams::PlayerSelectUid;
        body["team_id"] = NetParams::TeamSelectId;
        Network::Post("ChangePlayerTeam", body, false);
    }

    void ActivatePowerup() {
        auto body = Json::Object();
        body["powerup"] = int(NetParams::Powerup);
        body["board_index"] = NetParams::PowerupBoardIndex;
        body["forwards"] = NetParams::PowerupBoardIsForward;
        body["player_uid"] = NetParams::PlayerSelectUid;
        body["choice"] = NetParams::PowerupChoiceIndex;
        Network::Post("ActivatePowerup", body, true);
    }

    void GetDiceChoices() {
        auto request = Network::Post("GetDiceChoices", Json::Object(), true);
        if (@request is null) return;

        UIItemSelect::MapChoices = {};
        for (uint i = 0; i < request["maps"].Length; i++) {
            UIItemSelect::MapChoices.InsertLast(GameMap::Deserialize(request["maps"][i]));
        }
    }
}
