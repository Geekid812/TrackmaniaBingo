
namespace UILeaderboards {
    void Render() {
        UIColor::Navy();
        UI::BeginTabBar("##bingoleaderboards");

        if (UI::BeginTabItem("Seasonal Leaderboard")) {
            RenderSeasonals();
            UI::EndTabItem();
        }

        if (UI::BeginTabItem("Solo Records")) {
            RenderRecords();
            UI::EndTabItem();
        }

        UI::EndTabBar();
        UIColor::Reset();
    }

    void RenderSeasonals() {
        SeasonExplainerText();
        RenderLeaderboard("bingoseasonalleaderboard");
    }

    void RenderRecords() {

    }

    void SeasonExplainerText() {
        UI::PushStyleColor(UI::Col::ChildBg, vec4(.2, .3, .9, .1));
        UI::BeginChild("Season Explainer", vec2(0., 60.), UI::ChildFlags::AlwaysUseWindowPadding);
        
        UI::TextWrapped("Explainer Text.");
        
        UI::EndChild();
        UI::PopStyleColor();
    }

    void RenderLeaderboard(const string&in id) {
        UI::BeginTable(id, 3, UI::TableFlags::RowBg | UI::TableFlags::SizingFixedFit);
        uint offsetPosition = 0;
        for (uint i = 0; i < 10; i++) {
            uint currentRank = i + offsetPosition + 1;
            int score = 12000 - (1500 * i);
            PlayerProfile@ profile = DummyData();

            UI::TableNextColumn();
            UI::SetCursorPosX(UI::GetCursorPos().x + 8.);
            Font::Set(Font::Style::Bold, Font::Size::Medium);
            UI::Text(currentRank + ".");
            Font::Unset();

            UI::TableNextColumn();
            string titlePrefix = profile.title != "" ? "\\$" + profile.title.SubStr(0, 3) : "";
            UI::Text(titlePrefix + profile.name);
            if (UI::IsItemHovered()) {
                UI::BeginTooltip();
                UIProfile::RenderProfile(profile);
                UI::EndTooltip();
            }

            UI::TableNextColumn();
            Font::Set(Font::Style::Mono, Font::Size::Medium);
            Layout::AlignText(tostring(score), 1.0);
            UI::SetCursorPosX(UI::GetCursorPos().x - 8.);
            UI::Text(tostring(score));
            Font::Unset();
        }
        UI::EndTable();
    }

    PlayerProfile@ DummyData() {
        PlayerProfile profile();
        profile.countryCode = "FRA";
        profile.name = "Epic Player";
        profile.gamesPlayed = 12;
        return profile;
    }
}