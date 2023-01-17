
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
        @Regular = UI::LoadFont("assets/SofiaSans-Regular.ttf", 18, -1, -1, true, true, true);
        @Header = UI::LoadFont("assets/SofiaSans-Regular.ttf", 32);
        @Subtitle = UI::LoadFont("assets/SofiaSans-Regular.ttf", 26);
        @MonospaceBig = UI::LoadFont("DroidSansMono.ttf", 26);
        @Monospace = UI::LoadFont("DroidSansMono.ttf", 18, -1, -1, true);
        @Tiny = UI::LoadFont("assets/SofiaSans-Regular.ttf", 11);
        @Bold = UI::LoadFont("assets/SofiaSans-Bold.ttf", 18);
        @Condensed = UI::LoadFont("assets/SofiaSansSemiCondensed-Regular.ttf", 16);
    }
}