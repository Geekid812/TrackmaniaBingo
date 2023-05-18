
namespace UINews {
    bool Visible;

    void Render() {
        if (!Visible) return;
        UI::PushFont(Font::Regular);
        UI::Begin(Icons::NewspaperO + " News Reader##bingonews", Visible);
        for (uint i = 0; i < Config::News.Length; i++) {
            NewsItem(Config::News[i]);
            NewsCounter(i + 1, Config::News.Length);
            UI::Dummy(vec2(0, 30));
        }
        UI::End();
        UI::PopFont();
    }

    void NewsItem(Config::NewsItem item) {
        UI::PushFont(Font::Subtitle);
        UI::Text(item.title);
        UI::PopFont();
        UI::Separator();
        UI::TextWrapped(item.content);
        UI::Text("\\$aaa" + Icons::ClockO + " " + Timedelta(item.timestamp));
        if (item.linkNames.Length > 0) {
            UI::Text(Icons::Link);
        }
        for (uint i = 0; i < item.linkNames.Length; i++) {
            UI::SameLine();
            UI::Markdown("[" + item.linkNames[i] + "](" + item.linkHref[i] + ")");
        }
    }

    void NewsCounter(int current, int max) {
        string text = current + "/" + max;
        float padding = LayoutTools::GetPadding(UI::GetWindowSize().x, Draw::MeasureString(text, Font::Regular, Font::Regular.FontSize).x, 0.95);
        UI::SetCursorPos(vec2(padding, UI::GetCursorPos().y));
        UI::Text("\\$888" + text);
    }

    string Timedelta(int64 other) {
        int64 now = Time::Stamp;
        int64 delta = now - other;
        string fmt = "{} ago";
        if (delta < 0) {
            fmt = "in {}";
            delta = -delta;
        }
        return fmt.Replace("{}", RelativeTime(delta));
    }

    string RelativeTime(int64 delta) {
        const int weekSeconds = 60 * 60 * 24 * 7;
        const int daySeconds = 60 * 60 * 24;
        const int hourSeconds = 60 * 60;
        const int minuteSeconds = 60;

        int weeks = delta / weekSeconds;
        delta %= weekSeconds;
        int days = delta / daySeconds;
        delta %= daySeconds;
        int hours = delta / hourSeconds;
        delta %= hourSeconds;
        int minutes = delta / minuteSeconds;
        delta %= minuteSeconds;

        if (weeks > 0) return weeks + " week" + (weeks > 1 ? "s" : "");
        if (days >= 3) return days + " days";
        if (days > 0) return days + " day" + (days > 1 ? "s" : "") + (hours == 0 ? "" : ", " + hours + " hour" + (hours == 1 ? "" : "s"));
        if (hours > 0) return hours + " hour" + (hours > 1 ? "s" : "");
        if (minutes >= 3) return minutes + " minutes";
        if (minutes > 0) return minutes + " minute" + (minutes > 1 ? "s" : "") + (delta == 0 ? "" : ", " + delta + " second" + (delta == 1 ? "" : "s"));
        return delta + " second" + (delta > 1 ? "s" : "");
    }
}