namespace TrackmaniaBingo {
    /**
     * Get the current context of the plugin. See the `State` enum for more information.
     */
    import State GetState() from "Bingo";
    /**
     * Returns whether a bingo game is active and the current loaded
     * map is on the bingo board. This indicates there is an available
     * time to load with `GetChallengeTargetTime()`.
     */
    import bool IsBingoMapActive() from "Bingo";
    /**
     * Get the time to beat of the current map.
     * If the map is not part of a Bingo game, returns 0.
     * If there is no target time (Target Medal: None), returns -1.
     */
    import int GetChallengeTargetTime() from "Bingo";
}