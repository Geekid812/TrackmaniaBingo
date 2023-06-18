const uint64 COUNTDOWN_TIME = 3000;

namespace Time {
    /**
     * Get the match's timelimit in milliseconds.
     */
    uint64 GetTimelimitMilliseconds() {
        if (@Match == null) return 0;
        return Match.config.minutesLimit * 60 * 1000;
    }

    /**
     * Get the milliseconds elapsed since game start.
     * Time does not increase after a game has ended.
     */
    uint64 MillisecondsElapsed() {
        if (@Match == null) return 0;
        uint64 curTime = Time::Now;
        if (Match.endState.HasEnded()) {
            curTime = Match.endState.EndTime;
        }
        return curTime - Match.startTimestamp - COUNTDOWN_TIME;
    }

    /**
     * Get the milliseconds remaining if playing on a time limit.
     */
    uint64 MillisecondsRemaining() {
        if (@Match == null) return 0;
        return GetTimelimitMilliseconds() - ClampedMillisecondsElapsed();
    }

    /**
     * Get the milliseconds elapsed since game start, but never exceeds the time limit.
     */
    uint64 ClampedMillisecondsElapsed() {
        if (@Match == null) return 0;
        if (Match.config.minutesLimit == 0) return MillisecondsElapsed();
        return Math::Clamp(MillisecondsElapsed(), 0, GetTimelimitMilliseconds());
    }
}