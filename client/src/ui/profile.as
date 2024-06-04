
namespace UIProfile {
    const string PLAYER_FLAG_URL = "https://trackmania.io/img/flags/";
    PlayerProfile@ openProfiles;

    void RenderProfile(PlayerProfile profile, bool showId = true) {
#if TMNEXT
        CountryFlag(profile.countryCode, vec2(30, 20));
        UI::SameLine();
        vec2 playerPos = UI::GetCursorPos();
        PlayerName(profile, true);
        if (profile.title != "") {
            NameTitle(profile.title);
        }

        MatchCount(profile.gamesPlayed);
        UI::SetCursorPos(playerPos);
        UI::NewLine();
        if (showId) PlayerId(profile.uid);
#elif TURBO
        PlayerName(profile, true);
#endif
    }

    void CountryFlag(const string&in countryCode, vec2 size) {
        Image flagImage(PLAYER_FLAG_URL + countryCode + ".jpg");
        if (@flagImage.data != null) {
            UI::Image(flagImage.data, size);
        } else {
            UI::Dummy(size);
        }
    }

    void PlayerName(PlayerProfile profile, bool bold) {
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

    void DailyMatchStats(int plays, int wins) {
        UI::Text(plays + " daily challenge" + (plays == 1 ? "" : "s")
        + " played \\$888(\\$8f8" + wins + " \\$888win" + (wins == 1 ? "" : "s") + ")");
    }

    void DailyWins(int wins) {
        UI::Text("\\$ffa" + wins + " daily challenge win" + (wins == 1 ? "" : "s"));
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

    void NameTitle(const string&in title) {
        auto parts = title.Split(":");
        if (parts.Length < 2) return;
        UI::SameLine();
        UI::Text("\\$" + parts[0] + parts[1]);
    }
}
