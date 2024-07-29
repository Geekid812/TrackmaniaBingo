const string MAIN_WINDOW_NAME = Icons::Th + " \\$zBingo";
const string MAIN_MENUITEM_NAME = "\\$ff0" + MAIN_WINDOW_NAME;

const string DEVELOPER_WINDOW_NAME = Icons::Th + " \\$zDeveloper Tools";
const string DEVELOPER_MENUITEM_NAME = "\\$82a" + DEVELOPER_WINDOW_NAME;

const string BINGO_REPO_URL = "https://github.com/Geekid812/TrackmaniaBingo";
const string BINGO_ISSUES_URL = "https://github.com/Geekid812/TrackmaniaBingo/issues";

#if TMNEXT
const GamePlatform CURRENT_GAME = GamePlatform::Next;
#elif TURBO
const GamePlatform CURRENT_GAME = GamePlatform::Turbo;
#endif

void Main() {
    // Initialization
    Font::Init();

    // Load configuration settings
    PersistantStorage::LoadItems();
    Config::FetchConfig();

    // If this is the first time, try to login to the game server
    Login::EnsureLoggedIn();


    // Plugin was connected to a game when it was forcefully closed or game crashed
    if (PersistantStorage::LastConnectedMatchId != "") {
        trace("[Main] Plugin was previously connected, attempting to reconnect.");
        Network::Connect();

        if (Network::IsConnected()) {
            NetParams::MatchJoinUid = PersistantStorage::LastConnectedMatchId;
            NetParams::MatchJoinTeamId = PersistantStorage::LastConnectedMatchTeamId;
            startnew(Network::Reconnect);
        }
    }

    // We are interested in roomlist notifications, so we should connect
    if (PersistantStorage::SubscribeToRoomUpdates) {
        trace("[Main] Player is subscribed to roomlist updates, connecting to the servers.");
        Network::Connect();
        UIRoomMenu::RoomsLoad = LoadStatus::Loading;
        startnew(Network::GetPublicRooms);
    }

    while (true) {
        Network::Loop();
        yield();
    }
}

void RenderMenu() {
    if (UI::MenuItem(MAIN_MENUITEM_NAME, "", UIMainWindow::Visible)) {
        UIMainWindow::Visible = !UIMainWindow::Visible;
        // Connect to server when opening plugin window the first time
        if (UIMainWindow::Visible && Network::GetState() == ConnectionState::Closed) {
            trace("[Main] Plugin window opened, connecting to the servers.");
            startnew(Network::Connect);
        }
    }

    if (Settings::DevTools && UI::MenuItem(DEVELOPER_MENUITEM_NAME, "", UIDevActions::Visible)) {
        UIDevActions::Visible = !UIDevActions::Visible;
    }
}

void Render() {
    if (!UI::IsGameUIVisible()) return;
    if (!Font::Initialized) return;
    Font::Set(Font::Style::Regular, Font::Size::Medium);

    UIGameRoom::Render();
    BoardLocator::Render();
    Board::Draw();
    UIInfoBar::Render();
    UIMapList::Render();
    UIPaintColor::Render();
    UITeams::Render();
    SettingsWindow::Render();
    UIChat::Render();

    for (uint i = 0; i < Polls.Length; i++) {
        UIPoll::RenderPoll(Polls[i], i);
    }

    if (Settings::DevTools) {
        UIDownloads::Render();
    }

    Font::Unset();
}

void RenderInterface() {
    if (!Font::Initialized) return;
    Font::Set(Font::Style::Regular, Font::Size::Medium);

    UIMainWindow::Render();
    UINews::Render();
    UIDailyHistory::Render();
    UIDevActions::Render();

    Font::Unset();
}

UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    return UIChat::OnKeyPress(down, key);
}

void Update(float dt) {
    if (@Match !is null) Game::Tick();
}
