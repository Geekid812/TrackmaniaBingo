
namespace UIProfile {
    const string PLAYER_FLAG_URL = "https://trackmania.io/img/flags/";
    PlayerProfile@ openProfiles;

    void RenderProfile(PlayerProfile profile, bool showId = true) {
        Font::Set(Font::Style::Regular, Font::Size::Medium);
        CountryFlag(profile.countryCode, vec2(30, 20));
        UI::SameLine();
        vec2 playerPos = UI::GetCursorPos();
        PlayerName(profile);
        if (profile.title != "") {
            NameTitle(profile.title);
        }

        MatchCount(profile.gamesPlayed);
        UI::SetCursorPos(playerPos);
        UI::NewLine();

        if (showId) {
            // Player UID is no longer shown on profile, skip
            UI::NewLine();
        }
        Font::Unset();
    }

    void CountryFlag(const string&in countryCode, vec2 size) {
        Image flagImage(PLAYER_FLAG_URL + countryCode + ".jpg");
        if (@flagImage.Data != null) {
            UI::Image(flagImage.Data, size);
        } else {
            UI::Dummy(size);
        }
    }

    void PlayerName(PlayerProfile profile) {
        UI::Text(profile.name);
    }

    void MatchCount(int matches) {
        UI::Text(matches + " \\$zmatch" + (matches == 1 ? "" : "es") + " played");
    }

    void MatchStats(int matches, int wins, int losses) {
        UI::Text(matches + " \\$zmatch" + (matches == 1 ? "" : "es")
        + " \\$888(\\$8f8" + wins + " \\$888win" + (wins == 1 ? "" : "s")
        + " /\\$f88 " + losses + " \\$888loss" + (losses == 1 ? "" : "es") + ")");
    }

    void RatingDisplay(int rating, int deviation) {
        string ratingText = "\\$ff8" + tostring(rating);
        if (deviation >= 150) {
            ratingText = "\\$ff8???";
        }
        ratingText += " \\$888±" + deviation;
        ratingText = "Score: " + ratingText;
        float padding = Layout::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(ratingText, Font::Current(), 16.).x, 0.95);
        Layout::MoveTo(padding);
        UI::Text(ratingText);
    }

    void PlayerId(int uid) {
        string idText = "\\$888Player ID: " + uid;
        float padding = Layout::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(idText, Font::Current(), 16.).x, 0.95);
        Layout::MoveTo(padding);
        UI::Text(idText);
    }

    void CreationDateDisplay(int64 timestamp) {
        Time::Info creationDate = Time::Parse(timestamp);

        string idText = "\\$888Joined " + MonthName(creationDate.Month) + " " + creationDate.Year;
        float padding = Layout::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(idText, Font::Current(), 16.).x, 0.95);
        Layout::MoveTo(padding);
        UI::Text(idText);
    }

    void NameTitle(const string&in title) {
        auto parts = title.Split(":");
        if (parts.Length < 2) return;
        UI::SameLine();
        UI::Text("\\$" + parts[0] + parts[1]);
    }

    string MonthName(int month) {
        const array<string> months = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"};
        return months[month - 1];
    }
}
