
namespace UIDaily {
    LoadStatus DailyLoad = LoadStatus::NotLoaded;
    dictionary DailyResults = {};
    LiveMatch@ DailyMatch;

    void DailyHome() {
        string formattedDate = Time::FormatStringUTC("%d %B %Y", Time::Stamp);
        UI::PushFont(Font::Subtitle);
        UI::Text("Daily Challenge - " + formattedDate);
        UI::PopFont();

        float buttonWidth = 124.;
        float padding = LayoutTools::GetPadding(UI::GetWindowSize().x, buttonWidth, 1.0);
        UI::SameLine();
        UIColor::Gray();
        LayoutTools::MoveTo(padding);
        if (UI::Button(Icons::ThList + " Show History")) {
            UIDailyHistory::Visible = !UIDailyHistory::Visible;
        }
        UIColor::Reset();
        UI::NewLine();
        
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
            DailyLoad = LoadStatus::Loading;
            NetParams::DailyResultDate = UIDaily::GetYesterdayTimestring();
            startnew(Network::LoadDailyChallenge);
            startnew(Network::GetDailyResults);
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

namespace UIDailyHistory {
    array<string> Months = {
        "", "January", "Febuary", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    };

    bool Visible;
    uint CurrentYear = Text::ParseUInt(Time::FormatStringUTC("%Y", Time::Stamp));
    uint CurrentMonth = Text::ParseUInt(Time::FormatStringUTC("%m", Time::Stamp));
    uint PageYear = CurrentYear;
    uint PageMonth = CurrentMonth;
    string LoadingTimestring;

    void DailyCalendarList(const string&in timestring) {
        for (uint d = 31; d > 0; d--) {
            string date = timestring + "-" + (d < 10 ? "0" : "") + d;
            if (UIDaily::DailyResults.Exists(date)) {
                DailyResult result;
                UIDaily::DailyResults.Get(date, result);
                string challengeText =
                "\\$fd8" + date + ": \\$z" + result.playerCount + " player"
                + (result.playerCount != 1 ? "s" : "") + " participated\n";

                if (result.winners.Length == 0) {
                    challengeText += "\n\\$aaaThere were no winners for this challenge.";
                } else {
                    array<string> winners;
                    for (uint i = 0; i < result.winners.Length; i++) winners.InsertLast(result.winners[i].name);
                    challengeText += "\n\\$ff6Winner" + (result.winners.Length > 1 ? "s" : "") + ": \\$z" + string::Join(winners, ", ");
                }

                UI::TextWrappedWindow(challengeText);
                UI::Separator();
            }
        }
    }

    void Render() {
        if (!Visible) return;
        UI::Begin(Icons::ThList + " Daily Challenge History", Visible);
        UIColor::Crimson();
        
        UI::BeginDisabled((PageMonth <= 9 || PageYear != 2023) && PageYear < 2024);
        if (UI::Button(Icons::ArrowLeft + "##dailyprevious")) {
            PageMonth -= 1;
            if (PageMonth == 0) {
                PageMonth = 12;
                PageYear -= 1;
            }
        }
        UI::EndDisabled();

        float size = UI::GetWindowSize().x;
        string date =  Months[PageMonth] + " " + tostring(PageYear);
        float padding = LayoutTools::GetPadding(size, Draw::MeasureString(date, Font::Regular, 16.).x, 0.5);
        UI::SameLine();
        LayoutTools::MoveTo(padding);
        UI::Text(date);

        float buttonWidth = 38.;
        padding = LayoutTools::GetPadding(size, buttonWidth, 1.0);
        UI::SameLine();
        LayoutTools::MoveTo(padding);
        UI::BeginDisabled((PageMonth >= CurrentMonth || PageYear != CurrentYear) && PageYear < CurrentYear + 1);
        if (UI::Button(Icons::ArrowRight + "##dailynext")) {
            PageMonth += 1;
            if (PageMonth == 13) {
                PageMonth = 1;
                PageYear += 1;
            }
        }
        UI::EndDisabled();

        UI::Separator();

        string timestring = PageYear + "-" + (PageMonth < 10 ? "0" : "") + PageMonth;
        if (UIDaily::DailyResults.Exists(timestring + "-01") || UIDaily::DailyResults.Exists(timestring + "-27")) {
            UI::BeginChild("dailycalendarlist");
            DailyCalendarList(timestring);
            UI::EndChild();
        } else {
            if (timestring == LoadingTimestring) {
                UI::Text("\\$ff4" + Icons::HourglassHalf + " \\$zLoading daily challenges...");
            } else {
                LoadingTimestring = timestring;
                NetParams::DailyResultDate = timestring + "-__";
                startnew(Network::GetDailyResults);
            }
        }

        UIColor::Reset();
        UI::End();
    }
}
