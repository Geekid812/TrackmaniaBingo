const string WindowName = Icons::Th + " \\$zBingo";
const string MenuItemName = "\\$ff0" + WindowName;

void Main() {
    Font::Init();
} 

void RenderMenu() {
    if (UI::MenuItem(MenuItemName, "", Window::Visible)) {
        Window::Visible = !Window::Visible;
    }
}

void Render() {
    Board::Draw();
    InfoBar::Render();
    MapList::Render();
}

void RenderInterface() {
    Window::Render();
}

void Update(float dt) {
    Tick(int(dt));
}

void OnDestroyed() {
    Network::EventStream.Close();
}