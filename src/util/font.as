
namespace Font {
    UI::Font@ Header;
    UI::Font@ Subtitle;
    UI::Font@ MonospaceBig;
    UI::Font@ Monospace;
    UI::Font@ Tiny;
    UI::Font@ Bold;

    void Init() {
        @Header = UI::LoadFont("DroidSans.ttf", 32);
        @Subtitle = UI::LoadFont("DroidSans.ttf", 26);
        @MonospaceBig = UI::LoadFont("DroidSansMono.ttf", 26);
        @Monospace = UI::LoadFont("DroidSansMono.ttf", 16);
        @Tiny = UI::LoadFont("DroidSans.ttf", 11);
        @Bold = UI::LoadFont("DroidSans-Bold.ttf", 16);
    }
}