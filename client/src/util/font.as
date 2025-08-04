
namespace Font {
    // Don't try to load another font if the size difference is smaller
    // than this bound (in pixels).
    const float FONT_SIZE_THRESHOLD = 3.;

    array<UI::Font @> FontCache_Regular;
    array<UI::Font @> FontCache_Bold;
    array<UI::Font @> FontCache_Mono;
    array<UI::Font @> FontStack;
    bool Initialized;

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

    class FontLoadCoroutineData {
        Style style;
        float size;

        FontLoadCoroutineData(Style style, float size) {
            this.style = style;
            this.size = size;
        }

    }

    void
    InsertFont(array<UI::Font @> @cache, UI::Font @font) {

        for (uint i = 0; i < cache.Length; i++) {
            if (font.FontSize <= cache[i].FontSize) {
                cache.InsertAt(i, font);
                return;
            }
        }

        cache.InsertLast(font);
    }

    UI::Font @RetrieveFont(array<UI::Font @> @cache, Size size) {
        float fontSize = int(size);
        for (uint i = 0; i < cache.Length; i++) {
            if (fontSize - FONT_SIZE_THRESHOLD <= cache[i].FontSize)
                return cache[i];
        }

        return cache[cache.Length - 1];
    }

    UI::Font @LoadFont(Style style, float size) {
        string fontName;
        array<UI::Font @> @fontCache;
        switch (style) {
        case Style::Regular:
            fontName = "droidsans.ttf";
            @fontCache = FontCache_Regular;
            break;
        case Style::Bold:
            fontName = "droidsans-bold.ttf";
            @fontCache = FontCache_Bold;
            break;
        case Style::Mono:
            fontName = "droidsansmono.ttf";
            @fontCache = FontCache_Mono;
            break;
        default:
            return null;
        }

        UI::Font @font = UI::LoadFont(fontName, size);

        if (@font is null) {
            warn("Fonts: null font loaded!");
        }

        InsertFont(fontCache, font);
        return font;
    }

    void LoadFontCoroutine(ref @data) {
        auto loadData = cast<FontLoadCoroutineData @>(data);
        LoadFont(loadData.style, loadData.size);
    }

    void Init() {
        // Load free fonts included by default in Openplanet
        LoadFont(Style::Regular, 16);
        LoadFont(Style::Regular, 20);
        LoadFont(Style::Regular, 26);
        LoadFont(Style::Bold, 16);
        LoadFont(Style::Mono, 16);

        trace("[Font::Init] Fonts loaded.");
        Initialized = true;
    }

    UI::Font @Get(Style style, Size size) {
        switch (style) {
        case Style::Regular:
            return RetrieveFont(FontCache_Regular, size);
        case Style::Bold:
            return RetrieveFont(FontCache_Bold, size);
        case Style::Mono:
            return RetrieveFont(FontCache_Mono, size);
        default:
            return null;
        }
    }

    // Set the current font style.
    void Set(Style style, Size size) {
        UI::Font @font = Get(style, size);

        float fontSize = int(size);
        float fontSizeDifference = Math::Abs(fontSize - font.FontSize);

        if (fontSizeDifference > FONT_SIZE_THRESHOLD) {
            // This font has an inaccurate size. Start a new font loading
            // request and, if completed, load a new matching font.
            startnew(LoadFontCoroutine, FontLoadCoroutineData(style, fontSize));
        }

        FontStack.InsertLast(font);
        UI::PushFont(font);
    }

    void Unset() {
        FontStack.RemoveLast();
        UI::PopFont();
    }

    // Get a handle to the current font in use.
    // Condition: Font stack not empty.
    UI::Font @Current() { return FontStack[FontStack.Length - 1]; }

    // Debugging function: display cache information in the UI.
    void InspectFontCache(array<UI::Font @>& in cache,
                          bool& out open,
                          const string& in windowName = "Font Cache Inspector") {
        UI::Begin(Icons::Bug + " " + windowName, open);
        for (uint i = 0; i < cache.Length; i++) {
            UI::Text(i + ": " + cache[i].FontSize);
        }
        UI::End();
    }
}
