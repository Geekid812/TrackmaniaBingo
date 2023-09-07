
namespace UIDaily {
    LoadStatus DailyLoad = LoadStatus::NotLoaded;
    LiveMatch@ DailyMatch;

    void DailyHome() {
        string formattedDate = Time::FormatStringUTC("%d %B %Y", Time::Stamp);
        UI::PushFont(Font::Subtitle);
        UI::Text("Daily Challenge - " + formattedDate);
        UI::PopFont();   
        UI::TextWrapped("A special bingo game with a 5x5 grid, random maps, gold medals, lasting all day everyday until midnight UTC.\n\nPlay at any time of the day and try to get a bingo line from these randomly selected maps. Be careful, everyone is playing at the same time on the same maps, and the bingos are only tallied up at the end of the day! Can you defend your maps and earn the win for today's challenge?\n\nNote: This mode is still a work in progress.");

        UI::NewLine();
        UITools::ConnectingIndicator();
        UITools::ErrorMessage("SubscribeDailyChallenge");
        if (Network::IsConnected()) {
            DailyShowGridPreview();
        }
        if (!UIMainWindow::Visible) DailyLoad = LoadStatus::NotLoaded;
    }

    void DailyShowGridPreview() {
        UITools::ErrorMessage("SubscribeDailyChallenge");
        if (DailyLoad == LoadStatus::NotLoaded) {
            startnew(Network::LoadDailyChallenge);
            DailyLoad = LoadStatus::Loading;
        }

        if (DailyLoad == LoadStatus::Loading) {
            LoadingIndicator();
            return;
        }

        if (DailyLoad == LoadStatus::Error) {
            ErrorIndicator();
            return;
        }

        if (@DailyMatch is null) {
            InactiveIndicator();
            return;
        }

        // Hardcoded to fit a 5x5 grid
        CenterRemainingSpace(446, 446);
        UI::BeginChild("bingodailygrid", vec2(446, 446), false);
        bool interacted = UIMapList::MapGrid(DailyMatch.gameMaps, DailyMatch.config.gridSize, 0.5, true);
        if (interacted) {
            @Match = DailyMatch;
            NetParams::MatchJoinUid = DailyMatch.uid;
            UIMainWindow::Visible = false;
            startnew(Network::JoinMatch);
        }
        UI::EndChild();

        UI::SetCursorPos(UI::GetCursorPos() - vec2(0., 48.));
        string countdownText = Time::Format(Math::Max(Time::MillisecondsRemaining(DailyMatch), 0), false, true, true);
        float padding = LayoutTools::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(countdownText, Font::Header, 26.).x, 0.5);
        LayoutTools::MoveTo(padding);
        UI::PushFont(Font::Header);
        UI::Text("\\$f90" + countdownText);
        UI::PopFont();
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

    void ErrorIndicator() {
        CenterText("Could not load the daily challenge.", Font::Regular);
    }

    void InactiveIndicator() {
        CenterText("The daily challenge is not currently active.", Font::Regular);
    }
}
