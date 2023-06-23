
namespace Animation {
    float GetProgress(float elapsed, float start, float duration, Easing easing = Easing::Linear) {
        return ComputeEasing(Math::Clamp((elapsed - start) / duration, 0., 1.), easing);
    }

    float ComputeEasing(float x, Easing e) {
        switch (e) {
            case Easing::Linear:
                return x;
            case Easing::SineIn:
                return 1 - Math::Cos((x * Math::PI) / 2);
            case Easing::SineOut:
                return Math::Sin((x * Math::PI) / 2);
            default:
                return 0;
        }
    }

    enum Easing {
        Linear,
        SineIn,
        SineOut,
    }
}