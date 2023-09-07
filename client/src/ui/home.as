namespace UIHome {
    void Render() {
        UI::SetWindowSize(vec2(550, 700), UI::Cond::FirstUseEver);
        Title();
        UI::Dummy(vec2(0, 20));
        if (Config::News.Length > 0) UINews::NewsItem(Config::News[0]);
        if (Config::News.Length > 1) {
            MoreNewsButton();
        }
    }

    void Title() {
        string title = "\\$ff5Trackmania Bingo \\$888" + Meta::ExecutingPlugin().Version;
        float titleSize = Draw::MeasureString(title, Font::Header, Font::Header.FontSize).x; 
        float titlePadding = LayoutTools::GetPadding(UI::GetWindowSize().x, titleSize, 0.5);
        UI::PushFont(Font::Header);
        UI::SetCursorPos(vec2(titlePadding, UI::GetCursorPos().y));
        UI::Text(title);
        UI::PopFont();
    }

    void MoreNewsButton() {
        UI::SameLine();
        UI::SetCursorPos(vec2(LayoutTools::GetPadding(UI::GetWindowSize().x, 120, 1.0), UI::GetCursorPos().y));
        UIColor::Cyan();
        if (UI::Button(Icons::ArrowRight + " More News")) {
            UINews::Visible = !UINews::Visible;
        }
        UIColor::Reset();
    }
}