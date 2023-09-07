
namespace Time {
    /**
     * Get the match's timelimit in milliseconds.
     */
    uint64 GetTimelimitMilliseconds(LiveMatch@ match) {
        if (@match == null) return 0;
        return match.config.minutesLimit * 60 * 1000;
    }

    /**
     * Get the match's no bingo time period in milliseconds.
     */
    uint64 GetNoBingoMilliseconds(LiveMatch@ match) {
        if (@match == null) return 0;
        return match.config.noBingoMinutes * 60 * 1000;
    }


    /**
     * Get the match's total max time, excluding overtime.
     */
    uint64 GetMaxTimeMilliseconds(LiveMatch@ match) {
        return GetTimelimitMilliseconds(match) + GetNoBingoMilliseconds(match);
    }

    /**
     * Get the milliseconds elapsed since game start.
     * Can be negative during the countdown phase.
     */
    int64 MillisecondsElapsed(LiveMatch@ match) {
        if (@match == null) return 0;
        uint64 curTime = Time::Now;
        return curTime - match.startTime;
    }

    /**
     * Get the milliseconds elapsed since game start.
     * Will always be strictly within the time limit range.
     */
    int64 MillisecondsBounded(LiveMatch@ match) {
        if (@match == null) return 0;
        if (match.config.minutesLimit == 0) return MillisecondsElapsed(match);
        return Math::Clamp(MillisecondsElapsed(match), 0, GetMaxTimeMilliseconds(match));
    }

    /**
     * Get the game's time in milliseconds. It is always within range and stops when the game has ended.
     */
    int64 Milliseconds(LiveMatch@ match) {
        if (@match == null) return 0;
        int64 millis = MillisecondsBounded(match);
        if (match.endState.HasEnded()) millis = match.endState.endTime - match.startTime;
        return millis;
    }

    /**
     * Get the milliseconds remaining if playing on a time limit.
     */
    int64 MillisecondsRemaining(LiveMatch@ match) {
        if (@match == null || match.config.minutesLimit == 0) return 0;
        return GetTimelimitMilliseconds(match) - MillisecondsElapsed(match) + GetNoBingoMilliseconds(match);
    }
}
