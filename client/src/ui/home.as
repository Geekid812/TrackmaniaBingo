namespace UIHome {
    array<string> Subtitles = {};
    uint SubtitleIndex = 0;

    void RandomizeSubtitle() {
        SubtitleIndex = Math::Rand(0, Subtitles.Length);
    }

    void Render() {
        UI::SetWindowSize(vec2(550, 700), UI::Cond::FirstUseEver);
        Title();
        Subtitle();
        UI::Dummy(vec2(0, 20));
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

        string subtitle = "\\$666" + Subtitles[SubtitleIndex];
        float titleSize = Draw::MeasureString(subtitle, Font::Current()).x; 
        float titlePadding = Layout::GetPadding(UI::GetWindowSize().x, titleSize, 0.5);
        UI::SetCursorPos(vec2(titlePadding, UI::GetCursorPos().y));
        UI::Text(subtitle);
    
        Font::Unset();
    }

    void InitSubtitles() {
        // WARNING: Large array initializers slow down the Angelscript extension.
        // This initalisation (although quite ugly) avoids the problem.
        Subtitles.InsertLast("BINGO BANGO");
        Subtitles.InsertLast("Fun with friends and enemies alike!");
        Subtitles.InsertLast("\"oh red team is cooking the diagonal\"");
        Subtitles.InsertLast("The Bingo grid strikes back");
        Subtitles.InsertLast("Game time to infinity and beyond!");
        Subtitles.InsertLast("100% Openplanet compatible!");
        Subtitles.InsertLast("If you're reading this, TMX is probably not down");
        Subtitles.InsertLast("Get in there and make your team proud!");
        Subtitles.InsertLast("It's all fun and games :)");
        Subtitles.InsertLast("\"Oh my god there's a kacky map\"");
        Subtitles.InsertLast("Nothing is unbeatable! (except when the DD2 map shows up)");
        Subtitles.InsertLast("Communication is your top priority!");
        Subtitles.InsertLast("Not sponsored by Wirtual!");
        Subtitles.InsertLast("Rules? What are they?");
        Subtitles.InsertLast("Not allowed to wallbang as per the NADEO Drivers contract.");
        Subtitles.InsertLast("Much better than Stunt mode!");
        Subtitles.InsertLast("Slightly better than Platform mode!");
        Subtitles.InsertLast("Multiplayer Versus for up to 9999 players!");
        Subtitles.InsertLast("Bingo for TMNF when?");
        Subtitles.InsertLast("Type 1 in chat if you see this!");
        Subtitles.InsertLast("No drivers license required!");
        Subtitles.InsertLast("Never gonna give you up!");
        Subtitles.InsertLast("Racing Edition™");
        Subtitles.InsertLast("Good fun since November 2022!");
        Subtitles.InsertLast("All is fine until YEPTREE");
        Subtitles.InsertLast("Completely unrelated to tax evasion!");
        Subtitles.InsertLast("Add your quote here when you become a champion!");
        Subtitles.InsertLast("Do not tell the console players!");
        Subtitles.InsertLast("Finally, you're ready!");
        Subtitles.InsertLast("Also check out Tic Tac Go!");
        Subtitles.InsertLast("Finally getting updated again!");
        Subtitles.InsertLast("Made me crash my game!");
    }
}
