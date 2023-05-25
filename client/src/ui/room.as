
namespace UIGameRoom {
    bool Visible;
    bool IncludePlayerCount;

    void Render() {
        if (@Room == null) Visible = false;
        if (!Visible) return;

        UI::PushStyleColor(UI::Col::TitleBg, UI::GetStyleColor(UI::Col::WindowBg));
        UI::PushStyleColor(UI::Col::TitleBgActive, UI::GetStyleColor(UI::Col::WindowBg));
        UI::PushStyleVar(UI::StyleVar::WindowTitleAlign, vec2(0.5, 0.5));
        UI::PushFont(Font::Bold);
        UI::SetNextWindowSize(600, 400, UI::Cond::Always);
        bool windowOpen = UI::Begin(Room.Config.Name + (IncludePlayerCount ? "\t\\$ffa" + Icons::Users + "  " + PlayerCount() : "") + "###bingoroom", Visible, UI::WindowFlags::NoResize);
        if (windowOpen) {
            UI::PushFont(Font::Regular);
            WindowMain();
            UI::PopFont();
        }
        IncludePlayerCount = !windowOpen;

        UI::End();
        UI::PopFont();
        UI::PopStyleVar();
        UI::PopStyleColor(2);
    }

    void WindowMain() {
        Window::RoomView();
    }

    string PlayerCount() {
        return Room.Players.Length + (Room.Config.HasPlayerLimit ? "/" + Room.Config.MaxPlayers : "");
    }
}
