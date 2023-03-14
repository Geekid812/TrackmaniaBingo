
namespace UITools {
    void AlignedLabel(const string&in text) {
        LayoutTools::BeginLabelAlign();
        UI::Text(text);
        UI::SameLine();
        LayoutTools::EndLabelAlign();
    }
}