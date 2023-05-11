
namespace Window {
    const uint[] TimeLimitOptions = { 15, 30, 45, 60, 90, 120 };
    const uint GridSizeMin = 3;
    const uint GridSizeMax = 8;
    bool Visible;
    bool JoinCodeVisible;
    bool RoomCodeVisible;
    bool RoomCodeHovered;
    bool ClipboardHovered;
    bool ClipboardCopied;
    string JoinCodeInput;
    FeaturedMappack@ SelectedPack;

    void Render() {
        if (!Visible) return;
        UI::Begin(WindowName, Visible);
        UI::PushFont(Font::Regular);

        if (!Permissions::PlayLocalMap()) {
            NoPermissions();
            UI::PopFont();
            UI::End();
            return;
        }

        if (Settings::DevMode) {
            DevControls();
            UI::Separator();
        }

        if (@Room != null && Room.InGame) {
            InGame();
            UI::PopFont();
            UI::End();
            return;
        }

        bool Disabled = false;
        if (@Room != null && !Room.InGame && Room.StartTime != 0) {
            Countdown();
            Disabled = true;
        }
        if (Network::RequestInProgress) {
            Disabled = true;
        }
        UI::BeginDisabled(Disabled);

        if (@Room != null) {
            RoomView();
        } else {
            if (Config::StatusMessage != "") {
                UI::Text("\\$z" + Icons::InfoCircle + " \\$ff0" + Config::StatusMessage);
            }
            OfflineIndicator();

            UI::BeginTabBar("Bingo_TabBar");

            if (UI::BeginTabItem(Icons::Home + " Home")) {
                UI::BeginChild("Home");
                HomeTab();
                UI::EndChild();
                UI::EndTabItem();
            }

            if (UI::BeginTabItem(Icons::ShareSquareO + " Join Room")) {
                UI::BeginChild("Join");
                JoinTab();
                UI::EndChild();
                UI::EndTabItem();
            }

            if (UI::BeginTabItem(Icons::PlusSquare + " Create Room")) {
                UI::BeginChild("Create");
                CreateTab();
                UI::EndChild();
                UI::EndTabItem();
            }

            UI::EndTabBar();
        }

        UI::EndDisabled();
        UI::PopFont();
        UI::End();
    }

    void HomeTab() {
        string header = "Trackmania Bingo: Version " + Meta::ExecutingPlugin().Version;
        float titlePadding = LayoutTools::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(header, Font::Header, 32).x, 0.5);
        UI::PushFont(Font::Header);
        UI::SetCursorPos(vec2(titlePadding, UI::GetCursorPos().y));
        UI::Text(header);
        UI::PopFont();

        UI::Text(Icons::Plug + " Plugin created by \\$ff0TheGeekid");
        UI::Text(Icons::Github + " Source code:");
        UI::SameLine();
        UI::Markdown("[Geekid812/TrackmaniaBingo](https://github.com/Geekid812/TrackmaniaBingo)");
        UI::Text(Icons::Bug + " Bug tracker:");
        UI::SameLine();
        UI::Markdown("[Report an Issue](https://github.com/Geekid812/TrackmaniaBingo/issues)");
        UI::Text(Icons::DiscordAlt + " Discord server:");
        UI::SameLine();
        UI::Markdown("[Trackmania Bingo](https://discord.gg/pJbeqptsEa)");

        UI::NewLine();
        for (uint i = 0; i < Config::News.Length; i++) {
            auto news = Config::News[i];
            UI::PushFont(Font::Subtitle);
            UI::Text(news.title + "\t\\$888" + news.postinfo);
            UI::PopFont();
            UI::Separator();
            UI::Markdown(news.content);
            UI::NewLine();
        }
    }

    void CreateTab() {
        SettingsView();
        CreateRoomButton();
        ConnectingIndicator();
    }

    void ConnectingIndicator() {
        if (Network::GetState() != ConnectionState::Connected && !Network::IsOffline) {
            UI::SameLine();
            UI::Text("\\$58f" + GetConnectingIcon() + " \\$zConnecting to server...");
        }
    }

    void OfflineIndicator() {
        if (Network::IsOffline) {
            UI::Text("\\$f44" + Icons::Exclamation + " \\$zOffline mode: Could not connect to server.");
            UI::SameLine();
            UIColor::Red();
            if (UI::Button(Icons::Repeat + " Retry")) {
                startnew(Network::Connect);
            }
            UIColor::Reset();
        }
    }

    string GetConnectingIcon() {
        int sequence = int(Time::Now / 333) % 3;
        if (sequence == 0)
            return Icons::Kenney::SignalLow;
        if (sequence == 1)
            return Icons::Kenney::SignalMedium;
        return Icons::Kenney::SignalHigh;
    }

    void SettingsView() {
        SettingsSection("Room Settings");
        RoomConfig.HasPlayerLimit = UI::Checkbox("##maxplayers", RoomConfig.HasPlayerLimit);
        UI::BeginDisabled(!RoomConfig.HasPlayerLimit);
        UI::SameLine();
        UI::SetNextItemWidth(200);
        RoomConfig.MaxPlayers = Math::Clamp(UI::InputInt("Player Limit", RoomConfig.MaxPlayers), 2, 100);
        UI::EndDisabled();

        // This doesn't exist... yet
        if (false) RoomConfig.RandomizeTeams = UI::Checkbox("Randomize Teams", RoomConfig.RandomizeTeams);
        if (false) RoomConfig.InGameChat = UI::Checkbox("In-Game Chat", RoomConfig.InGameChat);

        SettingsSection("Game Settings");
        if (UI::BeginCombo("Grid Size", tostring(RoomConfig.GridSize) + "x" + tostring(RoomConfig.GridSize))) {
            
            for (uint i = GridSizeMin; i <= GridSizeMax; i++) {
                if (UI::Selectable(tostring(i) + "x" + tostring(i), RoomConfig.GridSize == i)) {
                    RoomConfig.GridSize = i;
                }
            }

            UI::EndCombo();
        }
        if (UI::BeginCombo("Map Selection", @SelectedPack != null ? SelectedPack.name : stringof(RoomConfig.MapSelection))) {
            if (UI::Selectable(stringof(MapMode::TOTD), RoomConfig.MapSelection == MapMode::TOTD)) {
                RoomConfig.MapSelection = MapMode::TOTD;
                @SelectedPack = null;
            }

            if (UI::Selectable(stringof(MapMode::MXRandom), RoomConfig.MapSelection == MapMode::MXRandom)) {
                RoomConfig.MapSelection = MapMode::MXRandom;
                @SelectedPack = null;
            }

            if (UI::Selectable(stringof(MapMode::Mappack), RoomConfig.MapSelection == MapMode::Mappack && @SelectedPack == null)) {
                RoomConfig.MapSelection = MapMode::Mappack;
                @SelectedPack = null;
            }

            for (uint i = 0; i < Config::featuredMappacks.Length; i++) {
                FeaturedMappack pack = Config::featuredMappacks[i];
                if (UI::Selectable("\\$ff8Featured Mappack: \\$z" + pack.name, @SelectedPack != null && SelectedPack.tmxid == pack.tmxid)) {
                    RoomConfig.MapSelection = MapMode::Mappack;
                    RoomConfig.MappackId = pack.tmxid;
                    @SelectedPack = pack;
                }
            }

            UI::EndCombo();
        }

        if (RoomConfig.MapSelection == MapMode::Mappack) {
            UI::BeginDisabled(@SelectedPack != null);
            RoomConfig.MappackId = UI::InputInt("TMX Mappack ID", RoomConfig.MappackId, 0);
            UI::EndDisabled();
        }

        if (UI::BeginCombo("Target Medal", stringof(RoomConfig.TargetMedal))) {
            if (UI::Selectable(stringof(Medal::Author), RoomConfig.TargetMedal == Medal::Author)) {
                RoomConfig.TargetMedal = Medal::Author;
            }

            if (UI::Selectable(stringof(Medal::Gold), RoomConfig.TargetMedal == Medal::Gold)) {
                RoomConfig.TargetMedal = Medal::Gold;
            }

            if (UI::Selectable(stringof(Medal::Silver), RoomConfig.TargetMedal == Medal::Silver)) {
                RoomConfig.TargetMedal = Medal::Silver;
            }
            if (UI::Selectable(stringof(Medal::Bronze), RoomConfig.TargetMedal == Medal::Bronze)) {
                RoomConfig.TargetMedal = Medal::Bronze;
            }
            if (UI::Selectable(stringof(Medal::None), RoomConfig.TargetMedal == Medal::None)) {
                RoomConfig.TargetMedal = Medal::None;
            }

            UI::EndCombo();
        }

        if (UI::BeginCombo("Time Limit", RoomConfig.MinutesLimit == 0 ? "Disabled" : tostring(RoomConfig.MinutesLimit) + " minutes")) {

            if (UI::Selectable("Disabled", RoomConfig.MinutesLimit == 0)) {
                RoomConfig.MinutesLimit = 0;
            }

            for (uint i = 0; i < TimeLimitOptions.Length; i++) {
                uint TimeOption = TimeLimitOptions[i];
                if (UI::Selectable(tostring(TimeOption) + " minutes", RoomConfig.MinutesLimit == TimeOption)) {
                    RoomConfig.MinutesLimit = TimeOption;
                }
            }

            UI::EndCombo();
        }
    }

    void CreateRoomButton() {
        UI::NewLine();
        bool disabled = !Config::CanPlay || Network::GetState() != ConnectionState::Connected;
        UI::BeginDisabled(disabled);
        UIColor::Lime();
        if (UI::Button(Icons::CheckCircle + " Create Room")) {
            startnew(Network::CreateRoom);
        }
        UIColor::Reset();
        UI::EndDisabled();
    }

    void SettingsSection(string&in text) {
        UI::NewLine();
        UI::PushFont(Font::Bold);
        UI::Text(text);
        UI::PopFont();
    }

    void JoinTab() {
        JoinCodeInput = UI::InputText("Room Code", JoinCodeInput, false, UI::InputTextFlags::CharsUppercase | (JoinCodeVisible? 0 : UI::InputTextFlags::Password));
        UI::SameLine();
        JoinCodeVisible = UI::Checkbox("Show code", JoinCodeVisible);

        bool disabled = !Config::CanPlay || Network::GetState() != ConnectionState::Connected;
        if (disabled) UI::BeginDisabled();
        if (UI::Button("Join Room") && JoinCodeInput.Length >= 6) {
            startnew(Network::JoinRoom);
        }
        if (disabled) UI::EndDisabled();
        ConnectingIndicator();
    }

    void RoomView() {
        string playerStatus = StatusLabel(Icons::Users + " ", Room.Players.Length + (Room.Config.HasPlayerLimit ? "/" + Room.Config.MaxPlayers : ""));
        UI::Text(playerStatus);
        if (UI::IsItemHovered()) {
            StatusTooltip("", Room.Players.Length + (Room.Players.Length == 1 ? " player" : " players"));
        }
    
        UI::SameLine();
        string roomCodeStatus = StatusLabel((RoomCodeHovered ? "\\$ff8" : "") + Icons::Kenney::Key, RoomCodeVisible ? Room.JoinCode : "******");
        UI::PushFont(Font::Monospace);
        UI::Text(roomCodeStatus);
        UI::PopFont();
        if (UI::IsItemClicked()) RoomCodeVisible = !RoomCodeVisible;
        RoomCodeHovered = UI::IsItemHovered();
        if (RoomCodeHovered) {
            StatusTooltip("Room Code", RoomCodeVisible ? Room.JoinCode : "\\$aaaHidden  (Click to reveal)");
        }
        UI::SameLine();
        UI::Text((ClipboardHovered ? "\\$ff8" : "") + Icons::Clipboard);
        ClipboardHovered = UI::IsItemHovered();
        if (ClipboardHovered) {
            UI::BeginTooltip();
            UI::Text(ClipboardCopied ? "\\$8f8Room code copied!" : "\\$aaaClick to copy room code to clipboard");
            UI::EndTooltip();
        }
        if (UI::IsItemClicked()) {
            IO::SetClipboard(Room.JoinCode);
            ClipboardCopied = true;
        } else if (!ClipboardHovered) {
            ClipboardCopied = false;
        }

        UI::SameLine();
        float windowWidth = UI::GetWindowSize().x;
        float titleWidth = Draw::MeasureString(Room.Name, Font::Bold).x;
        float titlePadding = LayoutTools::GetPadding(windowWidth, titleWidth, 0.5);
        UI::SetCursorPos(vec2(titlePadding, UI::GetCursorPos().y));
        UI::PushFont(Font::Bold);
        UI::Text(Room.Name);
        UI::PopFont();

        if (Room.LocalPlayerIsHost) {
            UI::SameLine();
            float buttonPadding = LayoutTools::GetPadding(windowWidth, 150, 1.0);
            UI::SetCursorPos(vec2(buttonPadding, UI::GetCursorPos().y - 4));
            UIColor::Gray();
            if (UI::Button(Icons::Cog + " Change Settings")) {
                SettingsWindow::Visible = !SettingsWindow::Visible;
            }
            UIColor::Reset();
            UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 2));
        }
        UI::Separator();

        array<string> roomInfo = {
            StatusLabel(Icons::Th, tostring(Room.Config.GridSize) + "x" + tostring(Room.Config.GridSize)),
            StatusLabel(Icons::Map, tostring(Room.Config.MapSelection)),
            StatusLabel(Icons::Bullseye, stringof(Room.Config.TargetMedal)),
            StatusLabel(Icons::Hourglass, Room.Config.MinutesLimit == 0 ? "∞" : tostring(Room.Config.MinutesLimit) + ":00")
        };
        string combinedInfo = string::Join(roomInfo, " ");
        float infoPadding = LayoutTools::GetPadding(windowWidth, Draw::MeasureString(combinedInfo).x, 0.5);
        UI::SetCursorPos(vec2(infoPadding, UI::GetCursorPos().y));

        for (uint i = 0; i < roomInfo.Length; i++) {
            UI::Text(roomInfo[i]);

            if (UI::IsItemHovered()) {
                if (i == 0) {
                    StatusTooltip("Grid Size", tostring(Room.Config.GridSize) + "x" + tostring(Room.Config.GridSize));
                } else if (i == 1) {
                    StatusTooltip("Map Selection", stringof(Room.Config.MapSelection));
                } else if (i == 2) {
                    StatusTooltip("Target Medal", stringof(Room.Config.TargetMedal));
                } else {
                    StatusTooltip("Time Limit", Room.Config.MinutesLimit == 0 ? "Disabled" : tostring(Room.Config.MinutesLimit) + " minutes");
                }
            }

            UI::SameLine();
        }
        UI::NewLine();

        if (Room.MapsLoadingStatus != LoadStatus::LoadSuccess) {
            if (Room.MapsLoadingStatus == LoadStatus::Loading) {
                UI::Text("\\$ff0" + Icons::HourglassHalf + " \\$zFetching maps from TMX...");
            } else {
                UI::Text("\\$ff0" + Icons::ExclamationTriangle + " \\$ff6Maps could not be loaded from TMX. The game cannot be started.\nResponse from server: \\$f80" + Room.LoadFailInfo);
            }
        } else {
            UI::Text(""); // Blank space to avoid layout shifts
        }

        UI::BeginTable("Bingo_TeamTable", Room.Teams.Length + (Room.MoreTeamsAvaliable() ? 1 : 0));

        for (uint i = 0; i < Room.Teams.Length; i++) {
            UI::TableNextColumn();
            Team@ Team = Room.Teams[i];

            float seperatorSize = UI::GetContentRegionMax().x - UI::GetCursorPos().x - 50;
            UI::BeginChild("bingoteamsep" + i, vec2(seperatorSize, UI::GetTextLineHeightWithSpacing() + 4));
            UI::Text("\\$" + UIColor::GetHex(Team.Color) + Team.Name);

            UI::PushStyleColor(UI::Col::Separator, UIColor::GetAlphaColor(Team.Color, .8));
            UI::Separator();
            UI::PopStyleColor();
            UI::EndChild();

            if (UI::IsItemHovered()) {
                UI::BeginTooltip();
                UI::Text("\\$" + UIColor::GetHex(Team.Color) + Team.Name + " Team" + (Room.GetSelf().Team != Team ? "  \\$888(Click to join)" : ""));
                UI::EndTooltip();
            }

            if (UI::IsItemClicked()) {
                startnew(function(ref@ team) { Network::JoinTeam(cast<Team>(team)); }, Team);
            }
        }

        if (Room.MoreTeamsAvaliable()) {
            UI::TableNextColumn();
            if (UI::Button(Icons::PlusSquare + " Create team")) {
                startnew(Network::CreateTeam);
            }
        }

        uint RowIndex = 0;
        while (true) {
            // Iterate forever until no players in any team remain
            UI::TableNextRow();
            uint FinishedTeams = 0;
            for (uint i = 0; i < Room.Teams.Length; i++){
                // Iterate through all teams
                UI::TableNextColumn();
                Player@ Player = PlayerCell(Room.Teams[i], RowIndex);
                if (Player is null) { // No more players in this team
                    FinishedTeams += 1;
                    continue;
                }
                else {
                    UI::Text((Player.IsSelf ? "\\$ff8" : "") + (RowIndex + 1) + ". " + Player.Name);
                }
            }
            if (FinishedTeams == Room.Teams.Length) break;
            RowIndex += 1;
        }
        UI::EndTable();

        UIColor::DarkRed();
        if (UI::Button(Icons::Kenney::Exit + " Leave")) {
            startnew(Network::LeaveRoom);
        }
        UIColor::Reset();

        if (Room.LocalPlayerIsHost) {
            UIColor::DarkGreen();
            bool StartDisabled = (Room.Players.Length < 2 && !Settings::DevMode) || Room.MapsLoadingStatus != LoadStatus::LoadSuccess;
            UI::BeginDisabled(StartDisabled);
            
            UI::SameLine();
            if (UI::Button(Icons::PlayCircleO + " Start")) {
                startnew(Network::StartGame);
            }
            UI::EndDisabled();
            UIColor::Reset();
        }

        // Leave room if window was closed
        if (!Visible) Network::LeaveRoom();
    }

    string StatusLabel(const string&in icon, const string&in text) {
        return icon + " \\$z" + text;
    }

    void StatusTooltip(const string&in key, const string&in value) {
        UI::BeginTooltip();
        if (key != "") {
            UI::PushFont(Font::Bold);
            UI::Text(key + ":");
            UI::PopFont();
            UI::SameLine();
        }
        UI::Text(value);
        UI::EndTooltip();
    }

    void Countdown() {
        UI::PushFont(Font::Header);
        int SecondsRemaining = (Room.StartTime + CountdownTime - Time::Now) / 1000 + 1;
        UI::Text("Game starting in " + SecondsRemaining + "...");
        UI::PopFont();
        UI::NewLine();
        UI::Separator();
    }

    void InGame() {
        UI::Text("A game is already running! Close this window and keep playing!");
        if (UI::Button(Icons::Kenney::Exit + " Leave Game")) {
            startnew(Network::LeaveRoom);
        }
    }

    void NoPermissions() {
        UI::TextWrapped("Unfortunately, you do not have permission to play this gamemode.");
        UI::TextWrapped("Playing Bingo requires having at least \\$999Standard Access\\$z, which you do not seem to have. Sorry!");
        UI::TextWrapped("If you believe this is a mistake, make sure to restart your game and check your internet connection.");
    }

    void DevControls() {
        UIColor::Cyan();
        if (UI::Button(Icons::Signal + " Force Disconnect")) {
            startnew(Network::OnDisconnect);
        }
        UI::SameLine();
        if (UI::Button(Icons::Globe + " Test Connection")) {
            startnew(Network::TestConnection);
        }
        UI::SameLine();
        if (UI::Button(Icons::Plug + " Sync Client")) {
            startnew(Network::Sync);
        }
        UIColor::Reset();
    }
}

// Helper function to build the table
Player@ PlayerCell(Team team, int index) {
    int Count = 0;
    for (uint i = 0; i < Room.Players.Length; i++) {
        auto Player = Room.Players[i];
        if (Player.Team == team) {
            if (Count == index) return Player;
            else Count += 1;
        }
    }
    return null;
}

namespace SettingsWindow {
    bool Visible;

    void Render() {
        if (!Visible) return;
        UI::Begin(Icons::Th + " Room Settings", Visible, UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize);
        UI::PushFont(Font::Regular);
        Window::SettingsView();
        UI::NewLine();

        UIColor::Cyan();
        if (UI::Button(Icons::CheckCircle + " Update Settings")) {
            startnew(Network::EditRoomSettings);
        }
        UIColor::Reset();
        UI::NewLine();
        UI::PopFont();
        UI::End();
    }
}