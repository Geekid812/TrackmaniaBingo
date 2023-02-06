const uint64 CountdownTime = 3000;

namespace Time {
    /**
     * Get the room's timelimit in milliseconds.
     */
    uint64 GetTimelimitMilliseconds() {
        if (@Room == null) return 0;
        return Room.Config.MinutesLimit * 60 * 1000;
    }

    /**
     * Get the milliseconds elapsed since game start.
     */
    uint64 MillisecondsElapsed() {
        if (@Room == null) return 0;
        return Time::Now - Room.StartTime - CountdownTime;
    }

    /**
     * Get the milliseconds remaining if playing on a time limit.
     */
    uint64 MillisecondsRemaining() {
        if (@Room == null) return 0;
        return GetTimelimitMilliseconds() - ClampedMillisecondsElapsed();
    }

    /**
     * Get the milliseconds elapsed since game start, but never exceeds the time limit.
     */
    uint64 ClampedMillisecondsElapsed() {
        if (@Room == null) return 0;
        if (Room.Config.MinutesLimit == 0) return MillisecondsElapsed();
        return Math::Clamp(MillisecondsElapsed(), 0, GetTimelimitMilliseconds());
    }
}