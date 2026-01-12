
namespace Font {

    enum Style {
        Regular,
        Bold,
        Mono
    }

    enum Size {
        Small = 12,
        Medium = 16,
        Large = 20,
        XLarge = 26,
        XXLarge = 32,
        Huge = 38
    }

    UI::Font@ current = UI::Font::Default;
    UI::Font@ Current() {return current;}

    void Set(Style style, Size size) {
        if (style == Regular) {
            @current = UI::Font::Default;
        } else if (style == Bold) {
            @current = UI::Font::DefaultBold;
        } else if (style == Mono) {
            @current = UI::Font::DefaultMono;
        }
        UI::PushFont(current, size);
    }
    void Unset() {
        UI::PopFont();
    }
}
