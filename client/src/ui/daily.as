
namespace UIDaily {
    LoadStatus DailyLoad = LoadStatus::NotLoaded;
    dictionary DailyResults = {};
    LiveMatch@ DailyMatch;

    void DailyHome() {
        string formattedDate = Time::FormatStringUTC("%d %B %Y", Time::Stamp);
        UI::PushFont(Font::Subtitle);
        UI::Text("Daily Challenge - " + formattedDate);
        UI::PopFont();   
        UI::TextWrapped("A special bingo game with a 5x5 grid, random maps, gold medals, lasting all day everyday until midnight UTC.\n\nPlay at any time of the day and try to get a bingo line from these randomly selected maps. Be careful, everyone is playing at the same time on the same maps, and the bingos are only tallied up at the end of the day! Can you defend your maps and earn the win for today's challenge?");
        DailyYesterdayResults();

        UI::NewLine();
        UITools::ConnectingIndicator();
        UITools::ErrorMessage("SubscribeDailyChallenge");

        if (Network::IsConnected()) {
            DailyShowGridPreview();
        }
        if (!UIMainWindow::Visible) DailyLoad = LoadStatus::NotLoaded;
    }

    void DailyYesterdayResults() {
        string timestring = GetYesterdayTimestring();
        if (DailyResults.Exists(timestring)) {
            DailyResult result;
            DailyResults.Get(timestring, result);

            UI::Text("\\$ff4The winner" + (result.winners.Length == 1 ? "" : "s") +
            " for yesterday's challenge " + (result.winners.Length == 1 ? "is" : "are") + ": ");
            for (uint i = 0; i < result.winners.Length; i++) {
                UI::SameLine();
                vec2 pos = UI::GetCursorPos();
                if (pos.x > 10) pos.x -= 6;
                UI::SetCursorPos(pos);
                UI::TextWrappedWindow("\\$ff8" + result.winners[i].name);
            }

            if (result.winners.Length == 0) {
                UI::SameLine();
                UI::TextWrapped("\\$aaaNo winners...");
            }

            UI::SetCursorPos(UI::GetCursorPos() - vec2(0., UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).y));
            UI::TextWrappedWindow("\\$aaaTotal players: " + result.playerCount);
        }
    }

    void DailyShowGridPreview() {
        UITools::ErrorMessage("SubscribeDailyChallenge");
        if (DailyLoad == LoadStatus::NotLoaded) {
            startnew(Network::LoadDailyChallenge);
            startnew(Network::GetDailyResults);
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

    string GetYesterdayTimestring() {
        return Time::FormatStringUTC("%Y-%m-%d", Time::Stamp - (60 * 60 * 24));
    }
}
