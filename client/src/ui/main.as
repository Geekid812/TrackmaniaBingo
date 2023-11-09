const string BINGO_ISSUES_URL = "https://github.com/Geekid812/TrackmaniaBingo/issues";

enum LoadStatus {
    NotLoaded,
    Loading,
    Ok,
    Error
}

namespace UIMainWindow {
    bool Visible;

    bool ClipboardHovered;
    bool ClipboardCopied;

    enum WindowTab {
        Home,
        Play,
        Create
    }

    void Render() {
        if (!Visible) return;
        UI::PushFont(Font::Regular);

        bool offline = Network::IsOfflineMode();
        string title = (offline ? Icons::PowerOff + " Offline Mode" : "") + "###bingomain";
        vec4 titleColor = offline ? vec4(.5, .1, 0, .95) : UI::GetStyleColor(UI::Col::WindowBg);
        UI::PushStyleColor(UI::Col::TitleBg, UI::GetStyleColor(UI::Col::WindowBg));
        UI::PushStyleColor(UI::Col::TitleBgActive, titleColor);
        UI::Begin(title, Visible);

        RenderContent();

        UI::End();
        UI::PopStyleColor(2);
        UI::PopFont();
    }

    void RenderContent() {
        if (!Permissions::PlayLocalMap()) {
            NoPermissions();
            return;
        }

        if (Network::IsOfflineMode()) {
            UI::PushStyleColor(UI::Col::ChildBg, vec4(.3, .3, 0., .9));
            UI::PushStyleVar(UI::StyleVar::ChildBorderSize, .5f);
            UI::BeginChild("###bingooffline", vec2(0, 70), true);
            OfflineWarning();
            UI::EndChild();
            UI::PopStyleVar();
            UI::PopStyleColor();

            UI::Dummy(vec2(0, 20));
        }

        UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 10));
        if (@Profile != null) {
            UIProfile::RenderProfile(Profile);
        }
        UI::Dummy(vec2(0, 10));

        if (@Room != null || @Match != null) {
            InGameHeader();
        }
        
        UIColor::Crimson();
        UI::BeginTabBar("Bingo_TabBar");
        if (UI::BeginTabItem(Icons::Home + " Home")) {
            UI::BeginChild("bingohome");
            UIHome::Render();
            UI::EndChild();
            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::PlayCircle + " Play")) {
            UI::BeginChild("bingojoin");
            UIRoomMenu::RoomMenu();
            UI::EndChild();
            UI::EndTabItem();
        } else {
            if (UIRoomMenu::RoomsLoad != LoadStatus::NotLoaded && !PersistantStorage::SubscribeToRoomUpdates) {
                UIRoomMenu::RoomsLoad = LoadStatus::NotLoaded;
                startnew(Network::UnsubscribeRoomlist);
            }
            if (UIRoomMenu::RoomsLoad == LoadStatus::NotLoaded && PersistantStorage::SubscribeToRoomUpdates) {
                UIRoomMenu::RoomsLoad = LoadStatus::Loading;
                startnew(Network::GetPublicRooms);
            }
        }

        if (UI::BeginTabItem(Icons::PlusSquare + " Create")) {
            UI::BeginChild("bingocreate");
            CreateTab();
            UI::EndChild();
            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::Star + " Daily")) {
            UI::BeginChild("bingodaily");
            UIDaily::DailyHome();
            UI::EndChild();
            UI::EndTabItem();
        } else {
            if (UIDaily::DailyLoad != LoadStatus::NotLoaded) {
                if (@UIDaily::DailyMatch !is null) startnew(Network::UnsubscribeDailyChallenge);
                UIDaily::DailyLoad = LoadStatus::NotLoaded;
                @UIDaily::DailyMatch = null;
            }
        }


        UI::EndTabBar();
        UIColor::Reset();
    }

    void NoPermissions() {
        UI::TextWrapped("Unfortunately, you do not have permission to play this gamemode.");
        UI::TextWrapped("Playing Bingo requires having at least \\$999Standard Access\\$z, which you do not seem to have. Sorry!");
        UI::TextWrapped("If you believe this is a mistake, make sure to restart your game and check your internet connection.");
    }

    void CreateTab() {
        UIRoomSettings::SettingsView();
        CreateRoomButton();
        UITools::ConnectingIndicator();
        UITools::ErrorMessage("CreateRoom");
    }

    void CreateRoomButton() {
        UI::NewLine();
        bool disabled = !Config::CanPlay || !Network::IsConnected() || Network::IsUISuspended();
        UI::BeginDisabled(disabled);
        UIColor::Lime();
        if (UI::Button(Icons::CheckCircle + " Create Room")) {
            UIRoomSettings::SaveConfiguredSettings();
            startnew(Network::CreateRoom);
        }
        UIColor::Reset();
        UI::EndDisabled();
    }

    void OfflineWarning() {
        UI::Text("\\$ff4" + Icons::ExclamationTriangle + "  \\$zAn error occured while connecting to the Bingo server.");
        UIColor::Red();
        if (UI::Button(Icons::Repeat + " Retry")) {
            startnew(Network::Connect);
        }
        UIColor::Reset();
        UI::SameLine();
        UIColor::DarkRed();
        if (UI::Button(Icons::Bug + " Report Issue")) {
            OpenBrowserURL(BINGO_ISSUES_URL);
        }
        UIColor::Reset();
    }

    void InGameHeader() {
        UI::PushStyleColor(UI::Col::ChildBg, vec4(.9, .2, .2, .1));
        UI::PushStyleVar(UI::StyleVar::ChildBorderSize, .5f);
        UI::BeginChild("###bingoingame", vec2(0, 62), true);
        
        UI::PushFont(Font::Bold);
        UI::Text("\\$f44IN GAME");
        UI::PopFont();

        UI::SameLine();
        if (@Room !is null) {
            UIRoomMenu::RoomInfo(Room.NetworkState());
        } else {
            if (@UIDaily::DailyMatch !is null && Match.uid == UIDaily::DailyMatch.uid) {
                UI::PushFont(Font::Bold);
                UI::Text("Daily Challenge");
                UI::PopFont();
            } else {
                UI::NewLine();
            }

            UI::Text(string::Join(UIGameRoom::MatchConfigInfo(Match.config), "\t"));
        }

        UI::SameLine();
        float padding = LayoutTools::GetPadding(UI::GetWindowSize().x, Draw::MeasureString("\t\t\tLeave").x, 1.0);
        LayoutTools::MoveTo(padding);
        UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 4));
        UIGameRoom::LeaveButton();


        UI::EndChild();
        UI::PopStyleVar();
        UI::PopStyleColor();

        UI::Dummy(vec2(0, 20));
    }
}

namespace SettingsWindow {
    bool Visible;

    void Render() {
        if (!Visible) return;
        UI::Begin(Icons::Th + " Room Settings", Visible, UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize);
        UI::PushFont(Font::Regular);
        UIRoomSettings::SettingsView();
        UI::NewLine();

        UIColor::Cyan();
        if (UI::Button(Icons::CheckCircle + " Update Settings")) {
            UIRoomSettings::SaveConfiguredSettings();
            startnew(Network::EditConfig);
        }
        UIColor::Reset();
        UI::NewLine();
        UI::PopFont();
        UI::End();
    }
}
