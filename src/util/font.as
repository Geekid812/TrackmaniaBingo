
namespace Font {
    UI::Font@ Header;
    UI::Font@ Monospace;
    UI::Font@ Tiny;

    void Init() {
        @Header = UI::LoadFont("DroidSans.ttf", 32);
        yield(); // yield for script execution timeout
        @Monospace = UI::LoadFont("DroidSansMono.ttf", 26);
        yield();
        @Tiny = UI::LoadFont("DroidSans.ttf", 11);
    }
}