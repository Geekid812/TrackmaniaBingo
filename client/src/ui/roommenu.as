
namespace UIRoomMenu {
    string JoinCodeInput;
    bool JoinCodeVisible;
    LoadStatus RoomsLoad = LoadStatus::NotLoaded;
    array<NetworkRoom> PublicRooms;

    NetworkRoom@ GetRoom(const string&in code) {
        for (uint i = 0; i < PublicRooms.Length; i++) {
            if (PublicRooms[i].joinCode == code) return PublicRooms[i];
        }

        warn("Roomlist: GetRoom(" + code + ") returned null.");
        return null;
    }

    void SwitchToContext() {
        UIGameRoom::Visible = true;
        UIGameRoom::GrabFocus = true;
        UIMainWindow::Visible = false;
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

        float heightRemaining = UI::GetWindowSize().y - UI::GetCursorPos().y;
        float offset = 145. * UI::GetScale();
        UI::BeginChild("bingo_rooms", vec2(0, heightRemaining - offset), false);

        if (RoomsLoad == LoadStatus::Loading) {
            LoadingIndicator();
        } else if (RoomsLoad == LoadStatus::Error) {
            UI::Text("\\$888Public rooms failed to load.");
            UI::SameLine();
            UITools::ReconnectButton();
        } else {
            if (PublicRooms.Length == 0) {
                UI::Text("\\$888There are no open public rooms at the moment.\nGo ahead and create one!");
                UI::EndChild();
                return;
            }

            UI::PushStyleColor(UI::Col::TableBorderLight, vec4(.9, 1));
            if (!UI::BeginTable("bingo_publicrooms", 1, UI::TableFlags::BordersInnerH)) {
                // Table is not visible, return early and do not call EndTable().
                UI::PopStyleColor();
                UI::EndChild();
                return;
            }
            for (uint i = 0; i < PublicRooms.Length; i++) {
                NetworkRoom room = PublicRooms[i];
                UI::TableNextColumn();
                UI::SetCursorPos(UI::GetCursorPos() + vec2(0, 8));
                float x = UI::GetCursorPos().x;
                RoomInfo(room);
                UI::SameLine();
                float y = UI::GetCursorPos().y;
                vec2 base = vec2(x, y);

                bool inGame = room.startedTimestamp != 0;
                string buttonText = Icons::Play + "  Join";
                if (inGame) buttonText = Icons::PlayCircleO + "  In Game";

                if (inGame) {
                    string timer;
                    if (uint64(Time::Stamp) >= room.startedTimestamp) timer = "\\$f80" + Time::Format((Time::Stamp - room.startedTimestamp) * 1000, false, true, true);
                    else timer = "\\$f80Game starting in " + (room.startedTimestamp - Time::Stamp) + "...";
                    float padding = LayoutTools::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(timer).x, 0.75);
                    UI::SetCursorPos(base + vec2(padding, 4.));
                    UI::Text(timer);
                }

                float padding = LayoutTools::GetPadding(UI::GetWindowSize().x, Draw::MeasureString("\t" + buttonText).x, 1.0);
                UI::SetCursorPos(base + vec2(padding, 0.));
                UI::BeginDisabled(inGame);
                if (!inGame) UIColor::DarkGreen();
                else UIColor::Orange();

                if (UI::Button(buttonText)) {
                    NetParams::JoinCode = room.joinCode;
                    startnew(Network::JoinRoom);
                }

                UIColor::Reset();
                UI::EndDisabled();
                UI::SetCursorPos(UI::GetCursorPos() + vec2(0, 4));
                UI::Dummy(vec2());
            }
            UI::TableNextColumn();
            UI::EndTable();
            UI::PopStyleColor();
        }
        UI::EndChild();
    }

    void RoomInfo(NetworkRoom room) {
        vec2 base = UI::GetCursorPos();
        UI::PushFont(Font::Bold);
        UI::Text(room.name);
        UI::PopFont();

        string righttext = Icons::Users + " " + room.playerCount + (room.config.size != 0 ? "/" + room.config.size : "") + "\t" + (room.hostName != "" ? ("\t" + Icons::User + " " + room.hostName) : "");
        float padding = LayoutTools::GetPadding(UI::GetWindowSize().x - base.x, Draw::MeasureString(righttext).x, 1.0);
        UI::SetCursorPos(base + vec2(padding, 0.));
        UI::Text(righttext);
        UI::Text(string::Join(UIGameRoom::MatchConfigInfo(room.matchConfig), "\t"));
    }

    void SubscribeCheckbox() {
        PersistantStorage::SubscribeToRoomUpdates = UI::Checkbox("Send a notification when a new public game is created", PersistantStorage::SubscribeToRoomUpdates);
    }

    void RoomMenu() {
        UITools::SectionHeader("Public Rooms");
        if (Network::GetState() == ConnectionState::Connected) {
            PublicRoomList();
        }

        UITools::SectionHeader("Join a Private Room");
        RoomCodeInput();

        UI::BeginDisabled(!Config::CanPlay || !Network::IsConnected() || Network::IsUISuspended());
        JoinPrivateRoomButton();
        UI::EndDisabled();

        UITools::ConnectingIndicator();
        UI::NewLine();
        UI::Separator();
        SubscribeCheckbox();
    }
}