
namespace Time {
    /**
     * Get the match's timelimit in milliseconds.
     */
    uint64 GetTimelimitMilliseconds() {
        if (@Match == null) return 0;
        return Match.config.minutesLimit * 60 * 1000;
    }

    /**
     * Get the match's no bingo time period in milliseconds.
     */
    uint64 GetNoBingoMilliseconds() {
        if (@Match == null) return 0;
        return Match.config.noBingoMinutes * 60 * 1000;
    }


    /**
     * Get the match's total max time, excluding overtime.
     */
    uint64 GetMaxTimeMilliseconds() {
        return GetTimelimitMilliseconds() + GetNoBingoMilliseconds();
    }

    /**
     * Get the milliseconds elapsed since game start.
     * Can be negative during the countdown phase.
     */
    int64 MillisecondsElapsed() {
        if (@Match == null) return 0;
        uint64 curTime = Time::Now;
        return curTime - Match.startTime;
    }

    /**
     * Get the milliseconds elapsed since game start.
     * Will always be strictly within the time limit range.
     */
    int64 MillisecondsBounded() {
        if (@Match == null) return 0;
        if (Match.config.minutesLimit == 0) return MillisecondsElapsed();
        return Math::Clamp(MillisecondsElapsed(), 0, GetMaxTimeMilliseconds());
    }

    /**
     * Get the milliseconds remaining if playing on a time limit.
     */
    int64 MillisecondsRemaining() {
        if (@Match == null || Match.config.minutesLimit == 0) return 0;
        return GetTimelimitMilliseconds() - MillisecondsElapsed() + GetNoBingoMilliseconds();
    }
}
