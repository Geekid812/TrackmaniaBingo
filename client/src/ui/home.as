namespace UIHome {
    const float FOOTER_SIZE = 48;
    array<string> Subtitles = {};
    uint SubtitleIndex = 0;

    void RandomizeSubtitle() { SubtitleIndex = Math::Rand(0, Subtitles.Length); }

    void Render() {
        UI::SetWindowSize(vec2(550, 700), UI::Cond::FirstUseEver);
        Title();
        Subtitle();
        UI::Dummy(vec2(0, 20));
        if (Config::News.Length > 0)
            UINews::NewsItem(Config::News[0]);

        LinksFooter();
    }

    void Title() {
        Font::Set(Font::Style::Bold, Font::Size::XXLarge);

        string title = PLUGIN_TITLE;
        float titleSize = Draw::MeasureString(title).x;
        float titlePadding = Layout::GetPadding(UI::GetWindowSize().x, titleSize, 0.5);
        UI::SetCursorPos(vec2(titlePadding, UI::GetCursorPos().y));
        UI::Text(title);

        Font::Unset();
    }

    void Subtitle() {
        Font::Set(Font::Style::Regular, Font::Size::Large);

        string subtitle = "\\$666" + Subtitles[SubtitleIndex];
        float titleSize = Draw::MeasureString(subtitle).x;
        float titlePadding = Layout::GetPadding(UI::GetWindowSize().x, titleSize, 0.5);
        UI::SetCursorPos(vec2(titlePadding, UI::GetCursorPos().y));
        UI::Text(subtitle);

        Font::Unset();
    }

    void InitSubtitles() {
        // WARNING: Large array initializers slow down the Angelscript extension.
        // This initalisation (although quite ugly) avoids the problem.
        Subtitles.InsertLast("Fun with friends and enemies alike!");
        Subtitles.InsertLast("Available Monday through Sunday, even when COTD is down!");
        Subtitles.InsertLast("The Bingo grid strikes back.");
        Subtitles.InsertLast("Game time to infinity and beyond!");
        Subtitles.InsertLast("100% Openplanet compatible!");
        Subtitles.InsertLast("Powered by Trackmania Exchange!");
        Subtitles.InsertLast("Get in there and make your team proud!");
        Subtitles.InsertLast("It's all fun and games :)");
        Subtitles.InsertLast("Just pray you don't get a Kacky map!");
        Subtitles.InsertLast("No map is ever unbeatable!");
        Subtitles.InsertLast("Communication is your top priority!");
        Subtitles.InsertLast("Not sponsored by Ubisoft Nadeo!");
        Subtitles.InsertLast("Play with your own rules!");
        Subtitles.InsertLast("Do whatever it takes to overcome the challanges ahead!");
        Subtitles.InsertLast("Much better than Stunt mode!");
        Subtitles.InsertLast("Slightly better than Platform mode!");
        Subtitles.InsertLast("Multiplayer Versus for up to 9999 players!");
        Subtitles.InsertLast("Who even reads these subtitles?");
        Subtitles.InsertLast("No drivers license required!");
        Subtitles.InsertLast("Never gonna give you up!");
        Subtitles.InsertLast("Racing Edition™");
        Subtitles.InsertLast("Good fun since November 2022!");
        Subtitles.InsertLast("All is fine until YEPTREE!");
        Subtitles.InsertLast("Completely unrelated to tax evasion!");
        Subtitles.InsertLast("A true display of skill!");
        Subtitles.InsertLast("Do not tell the console players!");
        Subtitles.InsertLast("Finally, you're ready!");
        Subtitles.InsertLast("Also check out Tic Tac Go!");
        Subtitles.InsertLast("Finally getting updated again!");
        Subtitles.InsertLast("Made me crash my game!");
        Subtitles.InsertLast("May your runs be blessed today!");
        Subtitles.InsertLast("Fight amongst the greatest!");
    }

    void LinksFooter() {
        Layout::MoveToY(UI::GetWindowSize().y - FOOTER_SIZE);
        UI::Separator();

        string unformattedText = "Discord - GitHub - Contact";
        Layout::AlignText(unformattedText, 0.5);

        UI::Markdown("[Discord](https://discord.gg/pJbeqptsEa) - "
                     "[GitHub](https://github.com/Geekid812/TrackmaniaBingo) - "
                     "[Contact](mailto:geekid812@gmail.com)");
        UITools::CenterTextDisabled(Icons::Code + " Made by Geekid");
    }
}
