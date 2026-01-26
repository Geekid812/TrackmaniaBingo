
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

    void Set(Style style, Size size) {
        UI::Font@ font;
        if (style == Regular) {
            @font = UI::Font::Default;
        } else if (style == Bold) {
            @font = UI::Font::DefaultBold;
        } else if (style == Mono) {
            @font = UI::Font::DefaultMono;
        }
        UI::PushFont(font, size);
    }
    void Unset() {
        UI::PopFont();
    }
}
