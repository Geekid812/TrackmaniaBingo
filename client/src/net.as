
namespace Network {
    const int SECRET_LENGTH = 32;
    const int POLL_RETRY_DELAY = 30;

    namespace __internal {
        // Disable UI interactions while a blocking request is happening
        bool SuspendUI = false;
        // Sequence counter for received events
        uint SequenceNext = 0;
        // Whether a polling loop is running
        bool IsPolling = false;
    }

    void ResetNetworkParameters() {
        __internal::SuspendUI = false;
        __internal::SequenceNext = 0;
     }

    bool IsUISuspended() {
        return __internal::SuspendUI;
    }

    void TestConnection() {
        uint64 start = Time::Now;
        auto response = API::MakeRequest(Net::HttpMethod::Get, "/me");
        uint64 end = Time::Now - start;
        bool result = response !is null;
        trace("[Network::TestConnection] " + tostring(result) + " in " + end + "ms");
    }

    void Handle(Json::Value@ body) {
        if (!body.HasKey("event")) {
            warn("Invalid message, discarding.");
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
            NetworkHandlers::AnnounceDraw();
        } else if (event == "MatchTeamCreated") {
            NetworkHandlers::MatchTeamCreated(body);
        } else if (event == "MatchPlayerJoin") {
            NetworkHandlers::MatchPlayerJoin(body);
        } else if (event == "RerollVoteCast") {
            NetworkHandlers::RerollVoteCast(body);
        } else if (event == "MapRerolled") {
            NetworkHandlers::MapRerolled(body);
        } else if (event == "CellPinged") {
            NetworkHandlers::CellPinged(body);
        } else if (event == "ChatMessage") {
            NetworkHandlers::ChatMessage(body);
        } else if (event == "PollStart") {
            NetworkHandlers::PollStart(body);
        } else if (event == "PollVotesUpdate") {
            NetworkHandlers::PollVotesUpdate(body);
        } else if (event == "PollResult") {
            NetworkHandlers::PollResult(body);
        } else {
            warn("[Network] Unknown event: " + string(body["event"]));
        }
    }

    void GetMyProfile() {
        Json::Value@ response = API::MakeRequestJson(Net::HttpMethod::Get, "/me");
        if (response is null) return;

        @Profile = PlayerProfile::Deserialize(response);
        PersistantStorage::LocalProfile = Json::Write(response);
    }

    void CreateRoom() {
        GameConfig.game = CURRENT_GAME;

        auto body = ChannelConfiguration::Serialize(RoomConfig);
        body["game_rules"] = GameRules::Serialize(GameConfig);

        Json::Value@ response = API::MakeRequestJson(Net::HttpMethod::Put, "/channels", Json::Write(body));
        if (response is null) return;

    }

    void ChannelOperationError() {
        err("Network", "An operation on this room could not be completed: Channel ID has not been defined.\nThis is a plugin error!");
    }

    void CreateTeam() {
        if (NetParams::ChannelId == "") {
            ChannelOperationError();
            return;
        }

        auto body = Json::Object();
        body["name"] = NetParams::TeamName;

        body["color"] = Json::Array();
        body["color"].Add(NetParams::TeamColor.x);
        body["color"].Add(NetParams::TeamColor.y);
        body["color"].Add(NetParams::TeamColor.z);
        
        Json::Value@ response = API::MakeRequestJson(Net::HttpMethod::Put, "/channels/" + NetParams::ChannelId + "/teams", Json::Write(body));
    }

    void DeleteTeam() {
        if (NetParams::ChannelId == "") {
            ChannelOperationError();
            return;
        }
          
        Json::Value@ response = API::MakeRequestJson(Net::HttpMethod::Delete, "/channels/" + NetParams::ChannelId + "/teams/" + NetParams::TeamId);
    }

    void JoinRoom() {
        Net::HttpRequest@ response = API::MakeRequest(Net::HttpMethod::Get, "/channels/resolve?code=" + NetParams::JoinCode);
        if (response is null) return;

        string channelId = response.String();
        NetParams::ChannelId = channelId;
        ConnectChannel();
    }

    void ConnectChannel() {
        if (NetParams::ChannelId == "") {
            ChannelOperationError();
            return;
        }

        Json::Value@ response = API::MakeRequestJson(Net::HttpMethod::Put, "/channels/" + NetParams::ChannelId + "/players?target_uid=" + User::GetUid());
        if (response is null) return;

        startnew(ChannelPollLoop);
    }

    void ChannelPollLoop() {
        __internal::IsPolling = true;
        try {
            ChannelPollLoopInner();
        } catch {
            // catch this exception to run destruction code and don't throw
            error("[Network] ChannelPollLoop threw an exception:" + getExceptionInfo());
        }
        __internal::IsPolling = false;
    }

    void ChannelPollLoopInner() {
        while (true) {
            if (NetParams::ChannelId == "") {
                warn("[Network::ChannelPollLoop] Channel ID is not defined, stopping loop.");
                return;
            }

            Json::Value@ response = API::MakeRequestJson(Net::HttpMethod::Get, "/channels/" + NetParams::ChannelId + "/poll");
            if (response is null) {
                warn("[Network::ChannelPollLoop] Polling failed, retrying in " + POLL_RETRY_DELAY + " seconds...");
                sleep(POLL_RETRY_DELAY * 1000);
                continue;
            }

            if (response.GetType() != Json::Type::Array) {
                err("Network::ChannelPollLoop", "Unexpected JSON! Expected a value of type Array, got " + tostring(response.GetType()));
                return;
            }

            for (uint i = 0; i < response.Length; i++) {
                // Handle a received event
                Handle(response[i]);
            }
        }
    }


    void JoinMatch() {

    }

    void GetPublicRooms() {

    }

    void EditConfig() {

    }

    void JoinTeam(Team team) {

    }

    void StartMatch() {

    }

    bool ClaimCell(int tileIndex, CampaignMap campaign, RunResult result) {
        return false;
    }

    void RerollCell() {

    }

    void SendChatMessage() {

    }

    void ReloadMaps() {

    }
}
