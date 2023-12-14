
namespace UIMapSelect {
    const uint BITS_PER_INT = 30;
    bool Visible;

    void Render() {
        if (!Visible) return;

        UI::Begin(Icons::Map + " Campaign Map Selection", Visible, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse);

        RenderCampaignSelect();

        UI::End();
    }

    void RenderCampaignSelect() {
        auto selectionBitfields = MatchConfig.campaignSelection;

        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(5, 3));
        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8, 6));
        if (UI::BeginTable("bingocampaignselect", 5, UI::TableFlags::BordersOuter)) {
            UI::TableNextColumn();
            array<string> headers = {"Canyon Grand Drift", "Down & Dirty Valley", "Rollercoaster Lagoon", "International Stadium"};
            array<vec3> headColors = {vec3(1., .7, .3), vec3(.1, .6, .1), vec3(.8, .3, .3), vec3(.1, .2, .4)};
            array<string> difficulties = {"White", "Green", "Blue", "Red", "Black"};
            array<vec4> colors = {vec4(1., 1., 1., .1), vec4(.4, 1., .4, .1), vec4(.4, .4, 1., .1), vec4(1., .4, .4, .1), vec4(.4, .4, .4, .1)};
            for (uint i = 0; i < headers.Length; i++) {
                UI::TableNextColumn();
                UIColor::Custom(headColors[i]);
                if (UI::Button(headers[i])) {
                    for (uint j = 0; j < 50; j++) {
                        int x = (30 * (j / 10) + 10 * i + j);
                        uint bitfieldIdx = x / BITS_PER_INT;
                        uint bitfieldMask = 1 << (x % BITS_PER_INT);
                        selectionBitfields[bitfieldIdx] ^= bitfieldMask;
                    }
                }
                UIColor::Reset();
            }
            for (uint i = 0; i < 200; i++) {
                uint bitfieldIdx = i / BITS_PER_INT;
                uint bitfieldMask = 1 << (i % BITS_PER_INT);
                if (i % 10 == 0) {
                    UI::TableNextColumn();
                }
                if (i % 40 == 0) {
                    UI::TableSetBgColor(UI::TableBgTarget::RowBg0, colors[i / 40]);
                    UI::NewLine();
                    UIColor::Custom(UIColor::Brighten(colors[i / 40].xyz, 0.8));
                    if (UI::Button(difficulties[i / 40])) {
                        for (uint j = i; j < i + 40; j++) {
                            bitfieldIdx = j / BITS_PER_INT;
                            bitfieldMask = 1 << (j % BITS_PER_INT);
                            selectionBitfields[bitfieldIdx] ^= bitfieldMask;
                        }
                    }
                    UIColor::Reset();
                    UI::TableNextColumn();
                }
                if (i % 5 != 0) UI::SameLine();

                bool disabled = (selectionBitfields[bitfieldIdx] & bitfieldMask) != 0;
                if (disabled) UIColor::Gray();
                if (UI::Button(Text::Format("%03i", i + 1))) {
                    selectionBitfields[bitfieldIdx] ^= bitfieldMask;
                }
                if (disabled) UIColor::Reset();
            }
            UI::EndTable();
        }
        UI::PopStyleVar(2);
    }
}