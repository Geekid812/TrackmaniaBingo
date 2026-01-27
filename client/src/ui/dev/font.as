namespace UIDevFonts {
    array<bool> FontCacheOpenState = {false, false, false};

    void RenderFontMatrix() {
        int numStyles = int(Font::Style::Mono) + 1;
        int maxSize = int(Font::Size::Huge) + 1;

        if (UI::BeginTable("bingodev_fonttable", numStyles)) {
            for (int x = 0; x < numStyles; x++) {
                UI::TableSetupColumn(tostring(Font::Style(x)));
            }
            UI::TableHeadersRow();

            for (int i = 0; i < maxSize; i++) {
                Font::Size size = Font::Size(i);

                // Check if the current size is named, otherwise skip
                if (tostring(size) == tostring(i))
                    continue;

                for (int j = 0; j < numStyles; j++) {
                    UI::TableNextColumn();
                    Font::Style style = Font::Style(j);
                    Font::Set(style, size);
                    UI::Text(tostring(size) + " (" + i + ")");
                    Font::Unset();
                }
            }

            for (int x = 0; x < numStyles; x++) {
                UI::TableNextColumn();

                if (UI::Button("Inspect Cache##bingodev_inspectfont" + x)) {
                    FontCacheOpenState[x] = !FontCacheOpenState[x];
                }
            }
            UI::EndTable();
        }
    }
}
