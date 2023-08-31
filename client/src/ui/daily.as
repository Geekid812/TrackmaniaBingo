
namespace UIDaily {
    LoadStatus DailyLoad = LoadStatus::NotLoaded;
    LiveMatch@ DailyMatch;

    void DailyHome() {
        string formattedDate = Time::FormatStringUTC("%d %B %Y", Time::Stamp);
        UI::PushFont(Font::Subtitle);
        UI::Text("Daily Challenge - " + formattedDate);
        UI::PopFont();   
        UI::TextWrapped("Blabla explaining the daily challenge.");

        UI::NewLine();
        DailyShowGridPreview();
    }

    void DailyShowGridPreview() {
        if (DailyLoad == LoadStatus::NotLoaded) {
            startnew(Network::LoadDailyChallenge);
            DailyLoad = LoadStatus::Loading;
        }

        if (DailyLoad == LoadStatus::Loading) {
            LoadingIndicator();
            return;
        }

        if (@DailyMatch is null) {
            InactiveIndicator();
            return;
        }

        // Hardcoded to fit a 5x5 grid
        CenterRemainingSpace(446, 446);
        UI::BeginChild("bingodailygrid", vec2(446, 0), false);
        UIMapList::MapGrid(DailyMatch.gameMaps, DailyMatch.config.gridSize, 0.5, false);
        UI::EndChild();
    }

    void CenterRemainingSpace(float width, float height) {
        float yOffset = UI::GetCursorPos().y;
        vec2 size = UI::GetWindowSize() - vec2(0, yOffset);
        float x = LayoutTools::GetPadding(size.x, width, 0.5);
        float y = LayoutTools::GetPadding(size.y, height, 0.5);
        UI::SetCursorPos(vec2(x, y + yOffset));
    }

    void CenterText(const string&in text, UI::Font@ font) {
        LayoutTools::MoveTo(LayoutTools::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(text, Font::Bold, Font::Bold.FontSize).x, 0.5));
        UI::PushFont(font);
        UI::Text(text);
        UI::PopFont();
    }

    void LoadingIndicator() {
        CenterText("Loading daily challenge...", Font::Bold);
    }

    void InactiveIndicator() {
        CenterText("The daily challenge is not currently active.", Font::Regular);
    }
}
