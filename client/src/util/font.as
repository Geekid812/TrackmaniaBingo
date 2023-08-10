
namespace Font {
    UI::Font@ Regular;
    UI::Font@ Header;
    UI::Font@ Title;
    UI::Font@ Subtitle;
    UI::Font@ MonospaceBig;
    UI::Font@ Monospace;
    UI::Font@ Tiny;
    UI::Font@ Bold;
    UI::Font@ Condensed;

    void Init() {
        @Regular = UI::LoadFont("assets/SofiaSans-Regular.ttf", 18, -1, -1, true, true, true);
        @Bold = UI::LoadFont("assets/SofiaSans-Bold.ttf", 18, -1, -1, true);
        @Title = UI::LoadFont("assets/SofiaSans-Bold.ttf", 36);
        @Subtitle = UI::LoadFont("assets/SofiaSans-Regular.ttf", 24);
        @Header = UI::LoadFont("assets/SofiaSans-Regular.ttf", 32);
        @MonospaceBig = UI::LoadFont("assets/Inconsolata-Medium.ttf", 26);
        @Monospace = UI::LoadFont("DroidSansMono.ttf", 18, -1, -1, true);
        @Tiny = UI::LoadFont("assets/SofiaSans-Regular.ttf", 11);
        @Condensed = UI::LoadFont("assets/SofiaSansSemiCondensed-Regular.ttf", 16);
    }
}
