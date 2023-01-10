
namespace LayoutTools {
    float GetPadding(float windowSize, float elementSize, float alignment) {
        return (windowSize - elementSize) * alignment;
    }
}