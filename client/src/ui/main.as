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

        if (!Permissions::PlayLocalMap()) {
            NoPermissions();
            return;
        }

        UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 10));
        if (@Profile != null) {
            UIProfile::RenderProfile(Profile);
        }
        UI::Dummy(vec2(0, 10));
        
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
        ConnectingIndicator();
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

    void ConnectingIndicator() {
        if (Network::GetState() == ConnectionState::Connecting) {
            UI::SameLine();
            UI::Text("\\$58f" + GetConnectingIcon() + " \\$zConnecting to server...");
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

    void OfflineWarning() {
        UI::Text("\\$ff4" + Icons::ExclamationTriangle + "  \\$zAn error occured while connecting to the Bingo server.");
        UIColor::Red();
        if (UI::Button(Icons::Repeat + " Retry")) {
            startnew(Network::Connect);
        }
        UIColor::Reset();
    }
/**

    
    void JoinTab() {
        UIRoomMenu::RoomMenu();
    }

    
    void InGame() {
        UI::Text("A game is already running! Close this window and keep playing!");
        if (UI::Button(Icons::Kenney::Exit + " Leave Game")) {
            startnew(Network::LeaveRoom);
        }
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
*/
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
