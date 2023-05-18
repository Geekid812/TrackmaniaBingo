const string WindowName = Icons::Th + " \\$zBingo";
const string MenuItemName = "\\$ff0" + WindowName;

void Main() {
    startnew(Font::Init);
    startnew(Login::EnsureLoggedIn);
    Config::FetchConfig();

    // Plugin was connected to a game when it was forcefully closed or game crashed
    if (WasConnected) {
        Network::Init();
    }

    while (true) {
        Network::Loop();
        yield();
    }
}

void RenderMenu() {
    if (UI::MenuItem(MenuItemName, "", Window::Visible)) {
        Window::Visible = !Window::Visible;
        // Connect to server when opening plugin window the first time
        if (Window::Visible && !Network::IsInitialized) {
            startnew(Network::Init);
        }
    }
}

void Render() {
    BoardLocator::Render();
    Board::Draw();
    InfoBar::Render();
    MapList::Render();
}

void RenderInterface() {
    Window::Render();
    UINews::Render();
    SettingsWindow::Render();
}

void Update(float dt) {
    Game::Tick();
}
