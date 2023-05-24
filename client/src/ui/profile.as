
namespace UIProfile {
    const string playerFlagUrl = "https://trackmania.io/img/flags/";
    PlayerProfile@ openProfiles;

    void RenderProfile(PlayerProfile profile) {
        CountryFlag(profile.countryCode, vec2(30, 20));
        UI::SameLine();
        vec2 playerPos = UI::GetCursorPos();
        PlayerName(profile, true);
        if (profile.title != "") {
            NameTitle(profile.title);
        }

        MatchCount(profile.matchCount, profile.wins, profile.losses);
        UI::SetCursorPos(playerPos);
        RatingDisplay(profile.score, profile.deviation);
        PlayerId(profile.uid);
    }

    void CountryFlag(const string&in countryCode, vec2 size) {
        auto flagImage = Images::CachedFromURL(playerFlagUrl + countryCode + ".jpg");
        if (@flagImage.m_texture != null) {
            UI::Image(flagImage.m_texture, size);
        } else {
            UI::Dummy(size);
        }
    }

    void PlayerName(PlayerProfile profile, bool bold) {
        UI::PushFont(bold ? Font::Bold : Font::Regular);
        UI::Text(profile.username);
        UI::PopFont();
    }

    void MatchCount(int matches, int wins, int losses) {
        UI::Text(matches + " match" + (matches == 1 ? "" : "es")
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
        float padding = LayoutTools::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(ratingText, Font::Regular, Font::Regular.FontSize).x, 0.95);
        LayoutTools::MoveTo(padding);
        UI::Text(ratingText);
    }

    void PlayerId(int uid) {
        string idText = "\\$888Player ID: " + uid;
        float padding = LayoutTools::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(idText, Font::Regular, Font::Regular.FontSize).x, 0.95);
        LayoutTools::MoveTo(padding);
        UI::Text(idText);
    }

    void NameTitle(const string&in title) {
        auto parts = title.Split(":");
        if (parts.Length < 2) return;
        UI::SameLine();
        UI::Text("\\$" + parts[0] + parts[1]);
    }
}