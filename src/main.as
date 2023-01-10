const string WindowName = Icons::Th + " \\$zBingo";
const string MenuItemName = "\\$ff0" + WindowName;

void Main() {
    startnew(Font::Init);
    Config::FetchConfig();
    Network::Init();

    while (true) {
        Network::Loop();
        yield();
    }
}

void RenderMenu() {
    if (UI::MenuItem(MenuItemName, "", Window::Visible)) {
        Window::Visible = !Window::Visible;
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
    SettingsWindow::Render();
}

// TODO: refactor so this is not using the Update callback
void Update(float dt) {
    Tick(int(dt));
}
