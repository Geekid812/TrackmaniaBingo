
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

    string GetWindowTitle() {
        return "";
    }

    vec4 GetWindowTitleColor() {
        return false ? vec4(.5, .1, 0, .95) : UI::GetStyleColor(UI::Col::WindowBg);
    }

    void Render() {
        if (!Visible) return;

        string title = GetWindowTitle() + "###bingomain";
        vec4 titleColor = GetWindowTitleColor();
        UI::PushStyleColor(UI::Col::TitleBg, UI::GetStyleColor(UI::Col::WindowBg));
        UI::PushStyleColor(UI::Col::TitleBgActive, titleColor);
        Window::Create(title, Visible, 600, 800);

        RenderContent();

        UI::End();
        UI::PopStyleColor(2);
    }

    void RenderContent() {
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
        }

        if (UI::BeginTabItem(Icons::PlusSquare + " Create")) {
            UI::BeginChild("bingocreate");
            CreateTab();
            UI::EndChild();
            UI::EndTabItem();
        }


        UI::EndTabBar();
        UIColor::Reset();
    }

    void CreateTab() {
        UIRoomSettings::SettingsView();
        CreateRoomButton();
    }

    void CreateRoomButton() {
        UI::NewLine();
        bool disabled = !Config::CanPlay || Network::IsUISuspended();
        UI::BeginDisabled(disabled);
        UIColor::Lime();
        if (UI::Button(Icons::CheckCircle + " Create Room")) {
            PersistantStorage::SaveConfigurations();
            startnew(Network::CreateRoom);
        }
        UIColor::Reset();
        UI::EndDisabled();
    }

    void OfflineWarning() {
        UI::Text("\\$ff4" + Icons::ExclamationTriangle + "  \\$zAn error occured while connecting to the Bingo server.");
        UIColor::Red();
        if (UI::Button(Icons::Repeat + " Retry")) {
            // TODO: no connection logic, eh?
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
        UI::BeginChild("###bingoingame", vec2(0, 72), true);
        
        UI::Text("\\$f44IN GAME");

        UI::SameLine();
        if (@Room !is null) {
            UIRoomMenu::RoomInfo(Room.NetworkState());
        } else {
            UI::NewLine();

            UI::Text(string::Join(UIGameRoom::MatchConfigInfo(Match.config), "\t"));
        }

        UI::SameLine();
        float padding = Layout::GetPadding(UI::GetWindowSize().x, Draw::MeasureString("\t\t\tLeave").x, 1.0);
        Layout::MoveTo(padding);
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
        UIRoomSettings::SettingsView();
        UI::NewLine();

        UIColor::Cyan();
        if (UI::Button(Icons::CheckCircle + " Update Settings")) {
            PersistantStorage::SaveConfigurations();
            startnew(Network::EditConfig);
        }
        UIColor::Reset();
        UI::NewLine();
        UI::End();
    }
}
