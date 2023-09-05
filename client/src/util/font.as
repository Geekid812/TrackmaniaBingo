
namespace Font {
    UI::Font@ Regular;
    UI::Font@ Header;
    UI::Font@ Subtitle;
    UI::Font@ MonospaceBig;
    UI::Font@ Monospace;
    UI::Font@ Tiny;
    UI::Font@ Bold;
    UI::Font@ Condensed;

    void Init() {
        @Regular = null;
        @Header = UI::LoadFont("droidsans.ttf", 26);
        @Subtitle = UI::LoadFont("droidsans.ttf", 20);
        @Monospace = UI::LoadFont("droid.ttf", 16);
        @Bold = UI::LoadFont("droidsans-bold.ttf", 16);
        @Condensed = null;

        // These font loads are not free to load and will require rebuilding
        // the font altas which can be expensive.
        @MonospaceBig = UI::LoadFont("droidsansmono.ttf", 26);
        @Tiny = UI::LoadFont("droidsans.ttf", 12);
    }
}
