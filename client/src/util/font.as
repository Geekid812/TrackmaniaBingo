
namespace Font {
    // Only attempt to load new requested fonts after the given delay in
    // milliseconds expires. It avoids loading fonts which were on display
    // for a shorter timeframe than this amount.
    const int64 FONT_LOAD_DELAY = 1500;

    array<UI::Font@> FontCache_Regular;
    array<UI::Font@> FontCache_Bold;
    array<UI::Font@> FontCache_Mono;
    array<UI::Font@> FontStack;
    uint64 FontRequest_CompletionTime;
    bool Initialized;

    void InsertFont(array<UI::Font@>@ cache, UI::Font@ font) {
        for (uint i = 0; i < cache.Length; i++) {
            if (font.FontSize <= cache[i].FontSize) {
                cache.InsertAt(i, font);
                return;
            }
        }

        cache.InsertLast(font);
    }

    UI::Font@ RetrieveFont(array<UI::Font@>@ cache, float size) {
        for (uint i = 0; i < cache.Length; i++) {
            if (size <= cache[i].FontSize) return cache[i];
        }

        return cache[cache.Length - 1];
    }

    UI::Font@ LoadFont(Style style, float size) {
        string fontName;
        array<UI::Font@>@ fontCache;
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
                fontName = "droid.ttf";
                @fontCache = FontCache_Mono;
                break;
            default:
                return null;
        }

        UI::Font@ font = UI::LoadFont(fontName, size);
        InsertFont(fontCache, font);
        return font;
    }

    void Init() {
        // Load free fonts included by default in Openplanet
        LoadFont(Style::Regular, 20);
        LoadFont(Style::Regular, 26);
        LoadFont(Style::Bold, 16);
        LoadFont(Style::Mono, 16);

        trace("Font: Fonts loaded.");
        Initialized = true;
    }

    UI::Font@ Get(Style style, float size) {
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

    void RequestFontLoad() {
        if (FontRequest_CompletionTime == 0) {
            FontRequest_CompletionTime = Time::Now + FONT_LOAD_DELAY;
        }
    }

    void Set(Style style, float size) {
        UI::Font@ font = Get(style, size);

        if (size != font.FontSize) {
            // This font has an inaccurate size. Start a new font loading
            // request and, if completed, load a new matching font.
            RequestFontLoad();

            if (Time::Now > FontRequest_CompletionTime) {
                @font = LoadFont(style, size);
            }
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
    UI::Font@ Current() {
        return FontStack[FontStack.Length - 1];
    }

    // Call every frame to reset an expired completion timestamp.
    void ResetLoadTimings() {
        if (FontRequest_CompletionTime != 0 && Time::Now > FontRequest_CompletionTime) {
            FontRequest_CompletionTime = 0;
        }
    }

    enum Style {
        Regular,
        Bold,
        Mono
    }
}
