
namespace Animation {
    /**
     * Get the animation time value using the given easing function.
     */
    float GetProgress(float elapsed, float start, float duration, Easing easing = Easing::Linear) {
        return ComputeEasing(Math::Clamp((elapsed - start) / duration, 0., 1.), easing);
    }

    /**
     * Compute the easing value by the function given by parameter e.
     */
    float ComputeEasing(float x, Easing e) {
        switch (e) {
            case Easing::Linear:
                return x;
            case Easing::SineIn:
                return 1 - Math::Cos((x * Math::PI) / 2);
            case Easing::SineOut:
                return Math::Sin((x * Math::PI) / 2);
            case Easing::SineInOut:
                return -(Math::Cos(Math::PI * x) - 1) / 2;
            case Easing::CubicIn:
                return x * x * x;
            case Easing::CubicOut:
                return 1 - Math::Pow(1 - x, 3);
            case Easing::CubicInOut:
                return x < 0.5 ? 4 * x * x *x : 1 - Math::Pow(-2 * x + 2, 3) / 2;
            default:
                return 0;
        }
    }

    /**
     * An easing function.
     */
    enum Easing {
        Linear,
        SineIn,
        SineOut,
        SineInOut,
        CubicIn,
        CubicOut,
        CubicInOut,
    }
}
