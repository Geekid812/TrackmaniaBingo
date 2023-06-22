
namespace UIRoomMenu {
    string JoinCodeInput;
    bool JoinCodeVisible;
    LoadStatus RoomsLoad = LoadStatus::NotLoaded;
    array<PublicRoom> Rooms;

    enum LoadStatus {
        NotLoaded,
        Loading,
        Ok,
        Error
    }

    class PublicRoom {
        string name;
        string hostname;
        string joinCode;
        int playerCount;
        RoomConfiguration config;
        MatchConfiguration matchConfig;

        PublicRoom() {}

        PublicRoom(Json::Value@ val) {
            name = val["name"];
            hostname = val["hostname"];
            joinCode = val["join_code"];
            playerCount = val["player_count"];
            config = RoomConfiguration::Deserialize(val["config"]);
            matchConfig = MatchConfiguration::Deserialize(val["match_config"]);
        }
    }

    void RoomCodeInput() {
        UITools::AlignedLabel("Room code");
        UI::SetNextItemWidth(200);
        JoinCodeInput = UI::InputText("##bingoroomcode", JoinCodeInput, false, UI::InputTextFlags::CharsUppercase | (JoinCodeVisible? 0 : UI::InputTextFlags::Password));
        UI::SameLine();
        bool colored = false;
        if (!JoinCodeVisible) {
            colored = true;
            UIColor::Gray();
        }
        if (UI::Button(JoinCodeVisible ? Icons::Eye : Icons::EyeSlash)) {
            JoinCodeVisible = !JoinCodeVisible;
        }
        if (colored) UIColor::Reset();
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UI::Text(JoinCodeVisible ? "Room code \\$8f8visible" : "Room code \\$888hidden");
            UI::EndTooltip();
        }
    }

    void JoinPrivateRoomButton() {
        if (UI::Button("Join Room") && JoinCodeInput.Length >= 6) {
            NetParams::JoinCode = JoinCodeInput;
            startnew(Network::JoinRoom);
        }
    }

    void LoadingIndicator() {
        UI::Text("\\$aa4" + Icons::Hourglass + " \\$zLoading public rooms...");
    }

    void PublicRoomList() {
        if (RoomsLoad == LoadStatus::NotLoaded) {
            startnew(Network::GetPublicRooms);
            RoomsLoad = LoadStatus::Loading;
        }

        if (RoomsLoad == LoadStatus::Loading) {
            LoadingIndicator();
        } else if (RoomsLoad == LoadStatus::Error) {
            UI::Text("\\$888Public rooms failed to load.");
        } else {
            if (Rooms.Length == 0) {
                UI::Text("\\$888There are no open public rooms at the moment.\nGo ahead and create one!");
                return;
            }

            UI::BeginChild("bingo_rooms");
            UI::PushStyleColor(UI::Col::TableBorderLight, vec4(.9, 1));
            UI::BeginTable("bingo_publicrooms", 1, UI::TableFlags::BordersInnerH);
            for (uint i = 0; i < Rooms.Length; i++) {
                PublicRoom room = Rooms[i];
                UI::TableNextColumn();
                UI::SetCursorPos(UI::GetCursorPos() + vec2(0, 8));
                vec2 base = UI::GetCursorPos();
                UI::PushFont(Font::Bold);
                UI::Text(room.name);
                UI::PopFont();

                string righttext = Icons::Users + " " + room.playerCount + (room.config.maxPlayers != 0 ? "/" + room.config.maxPlayers : "") + "\t\t" + Icons::User + " " + room.hostname;
                float padding = LayoutTools::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(righttext).x, 1.0);
                UI::SetCursorPos(base + vec2(padding, 0.));
                UI::Text(righttext);

                base = UI::GetCursorPos();
                UI::Text(string::Join(UIGameRoom::MatchConfigInfo(room.matchConfig), "\t"));
                padding = LayoutTools::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(Icons::Play + "\tJoin\t").x, 1.0);
                UI::SetCursorPos(base + vec2(padding, 0.));
                UIColor::DarkGreen();
                if (UI::Button(Icons::Play + " Join")) {
                    NetParams::JoinCode = room.joinCode;
                    startnew(Network::JoinRoom);
                }
                UIColor::Reset();

                UI::SetCursorPos(UI::GetCursorPos() + vec2(0, 4));
            }
            UI::TableNextColumn();
            UI::EndTable();
            UI::PopStyleColor();
            UI::EndChild();
        }
    }

    void RoomMenu() {
        UITools::SectionHeader("Public Rooms");
        if (Network::GetState() == ConnectionState::Connected) {
            PublicRoomList();
        }

        UI::NewLine();
        UITools::SectionHeader("Join a Private Room");
        RoomCodeInput();

        UI::BeginDisabled(!Config::CanPlay || !Network::IsConnected() || Network::IsUISuspended());
        JoinPrivateRoomButton();
        UI::EndDisabled();

        UIMainWindow::ConnectingIndicator();
    }
}