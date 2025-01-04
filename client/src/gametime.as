
namespace GameTime {
    /**
     * Get the game timer's current value, in milliseconds.
     */
    int64 CurrentClock() {
        if (!Gamemaster::IsBingoActive()) return 0;

        GamePhase phase = Gamemaster::GetPhase();
        int64 elapsedTime = CurrentTimeElapsed();
        bool isCountdown = Match.config.timeLimit != 0;

        switch (phase) {
            case GamePhase::NoBingo:
                return Match.config.noBingoDuration - elapsedTime;
            case GamePhase::Running:
                return isCountdown ? (Match.config.timeLimit - elapsedTime + Match.config.noBingoDuration) : elapsedTime - Match.config.noBingoDuration;
            case GamePhase::Overtime:
                return Time::Now - Match.overtimeStartTime;
            case GamePhase::Ended:
                return Match.endState.endTime - Match.startTime - Match.config.noBingoDuration;
        }
        return 0;
    }

    /**
     * Get the current text color code for the game timer.
     */
    string CurrentClockColorPrefix() {
        GamePhase phase = Gamemaster::GetPhase();
        switch (phase) {
            case GamePhase::NoBingo:
                return "\\$fe6";
            case GamePhase::Overtime:
                return "\\$e44+";
            case GamePhase::Ended:
                return "\\$fb0";
            default:
                return "\\$7e7";
        }
    }

    /**
     * Get the time elapased since the game started, in milliseconds.
     * Can be negative before the game has started.
     * Will be 0 if a start time was not specified.
     */
    int64 CurrentTimeElapsed() {
        int64 startTime = Gamemaster::GetStartTime();
        if (startTime == 0) return 0;

        int64 currentTime = Time::Now;
        return currentTime - startTime;
    }

    /**
     * Get the match's timelimit in normal phase, in milliseconds.
     */
    int64 GetRunningPhaseTime() {
        return Gamemaster::GetConfiguration().timeLimit;
    }

    /**
     * Get the match's no bingo time period in milliseconds.
     */
    int64 GetNoBingoPhaseTime() {
        return Gamemaster::GetConfiguration().noBingoDuration;
    }

    /**
     * Get the match's total max time, excluding overtime.
     */
    int64 GetMaxTimeMilliseconds() {
        return GetRunningPhaseTime() + GetNoBingoPhaseTime();
    }
}
