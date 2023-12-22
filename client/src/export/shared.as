namespace TrackmaniaBingo {
    /**
     * Possible contexts that are available in the plugin. This is not exhaustive,
     * it may be expanded upon in future plugin versions.
     */
    shared enum State {
        /** The player is not doing anything with the plugin. */
        None,
        /** The plugin main menu is open. */
        PluginMenu,
        /** Currently in a room lobby. */
        InRoom,
        /**
         * Currently in a bingo game.
         * This is not necesarily followed by `State::PostGame` if,
         * for example, the player leaves the game.
         */
        InGame,
        /**
         * A bingo game has just ended.
         * Upon exit, this will become `State::PluginMenu` or `State::None`.
         * Upon rejoining for a new game, this will transition to `State::InRoom`. 
         */
        PostGame,
    }
}
