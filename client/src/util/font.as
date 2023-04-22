
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
        sleep(1000);
        @Regular = UI::LoadFont("assets/SofiaSans-Regular.ttf", 18, -1, -1, true, true, true);
        yield();
        @Header = UI::LoadFont("assets/SofiaSans-Regular.ttf", 32);
        yield();
        @Subtitle = UI::LoadFont("assets/SofiaSans-Regular.ttf", 26);
        yield();
        @MonospaceBig = UI::LoadFont("assets/Inconsolata-Medium.ttf", 26);
        yield();
        @Monospace = UI::LoadFont("DroidSansMono.ttf", 18, -1, -1, true);
        yield();
        @Tiny = UI::LoadFont("assets/SofiaSans-Regular.ttf", 11);
        yield();
        @Bold = UI::LoadFont("assets/SofiaSans-Bold.ttf", 18, -1, -1, true);
        yield();
        @Condensed = UI::LoadFont("assets/SofiaSansSemiCondensed-Regular.ttf", 16);
    }
}