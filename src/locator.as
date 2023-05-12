
namespace BoardLocator {
    void Render() {
        if (@Room == null || !Room.InGame) return;

        float scale = UI::GetScale();

        UI::SetNextWindowPos(int((79 * Board::Unit()) / scale), int(Board::Unit() / scale), UI::Cond::FirstUseEver);
        UI::SetNextWindowSize(int((20 * Board::Unit()) / scale), int((20 * Board::Unit()) / scale), UI::Cond::FirstUseEver);

        UI::PushStyleColor(UI::Col::WindowBg, vec4(0, 0, 0, 0));
        UI::Begin("Board Locator", UI::WindowFlags::NoCollapse | UI::WindowFlags::NoTitleBar);
        Board::BoardSize = UI::GetWindowSize().y;
        Board::Position = UI::GetWindowPos();
        UI::SetWindowSize(vec2(Board::BoardSize, Board::BoardSize), UI::Cond::Always);
        UI::End();
        UI::PopStyleColor();
    }
}
