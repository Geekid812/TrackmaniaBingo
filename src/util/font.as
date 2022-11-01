
namespace Font {
    UI::Font@ Header;
    UI::Font@ Monospace;

    void Init() {
        @Header = UI::LoadFont("DroidSans.ttf", 32);
        @Monospace = UI::LoadFont("DroidSansMono.ttf", 26);
    }
}