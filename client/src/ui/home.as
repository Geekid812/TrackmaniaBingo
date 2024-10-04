namespace UIHome {
    const array<string> SUBTITLES = {
        "BINGO BANGO",
        "Fun with friends and enemies alike!",
        "\"oh red team is cooking the diagonal\"",
        "The Bingo grid strikes back",
        "Game time to infinity and beyond!",
        "100% Openplanet compatible!",
        "If you're reading this, TMX is probably not down",
        "Get in there and make your team proud!",
        "It's all fun and games :)",
        "\"Oh my god there's a kacky map\"",
        "Nothing in unbeatable! (except when the DD2 map shows up)",
        "Communication is your top priority!",
        "Not sponsored by Wirtual!",
        "Rules? What are they?",
        "Not allowed to wallbang as per the NADEO Drivers contract.",
        "Much better than Stunt mode!",
        "Slightly better than Platform mode!",
        "Multiplayer Versus for up to 9999 players!",
        "Bingo for TMNF when?",
        "Type 1 in chat if you see this!",
        "No drivers license required!",
        "Never gonna give you up!",
        "Racing Edition™",
        "Good fun since November 2022!",
        "All is fine until YEPTREE",
        "Completely unrelated to tax evasion!",
        "Add your quote here when you become a champion!",
        "Do not tell the console players!",
        "Finally, you're ready!",
        "Also check out Tic Tac Go!",
        "Finally getting updated again!",
        "Made me crash my game!"
    };
    uint SubtitleIndex = 0;

    void RandomizeSubtitle() {
        SubtitleIndex = Math::Rand(0, SUBTITLES.Length);
    }

    void Render() {
        UI::SetWindowSize(vec2(550, 700), UI::Cond::FirstUseEver);
        Title();
        Subtitle();
        UI::Dummy(vec2(0, 20));
        if (Config::News.Length > 0) UINews::NewsItem(Config::News[0]);
        if (Config::News.Length > 1) {
            MoreNewsButton();
        }
    }

    void Title() {
        Font::Set(Font::Style::Bold, Font::Size::XXLarge);

        string title = "\\$ff5Trackmania Bingo \\$888" + Meta::ExecutingPlugin().Version;
        float titleSize = Draw::MeasureString(title, Font::Current()).x; 
        float titlePadding = Layout::GetPadding(UI::GetWindowSize().x, titleSize, 0.5);
        UI::SetCursorPos(vec2(titlePadding, UI::GetCursorPos().y));
        UI::Text(title);
    
        Font::Unset();
    }

    void Subtitle() {
        Font::Set(Font::Style::Regular, Font::Size::Large);

        string subtitle = "\\$666" + SUBTITLES[SubtitleIndex];
        float titleSize = Draw::MeasureString(subtitle, Font::Current()).x; 
        float titlePadding = Layout::GetPadding(UI::GetWindowSize().x, titleSize, 0.5);
        UI::SetCursorPos(vec2(titlePadding, UI::GetCursorPos().y));
        UI::Text(subtitle);
    
        Font::Unset();
    }

    void MoreNewsButton() {
        string buttonText = Icons::ArrowRight + " More News";
        UI::SameLine();
        UI::SetCursorPos(vec2(Layout::GetPadding(UI::GetWindowSize().x, Layout::ButtonWidth(buttonText), 1.0), UI::GetCursorPos().y));
        UIColor::Cyan();
        if (UI::Button(buttonText)) {
            UINews::Visible = !UINews::Visible;
        }
        UIColor::Reset();
    }
}
