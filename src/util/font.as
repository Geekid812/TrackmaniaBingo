
namespace Font {
    UI::Font@ Header;
    UI::Font@ Monospace;

    void Init() {
        @Header = UI::LoadFont("DroidSans.ttf", 32);
        yield(); // yield for script execution timeout
        @Monospace = UI::LoadFont("DroidSansMono.ttf", 26);
    }
}