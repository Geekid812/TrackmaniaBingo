
namespace Gamemaster {
    namespace __internal {
        bool GameActive = false;
    }

    /**
     * Return `true` if the Bingo game is currently active.
     */
    bool IsBingoActive() { return __internal::GameActive; }

    /**
     * Activate/deactivate the Bingo game.
     */
    void SetBingoActive(bool active) {
        __internal::GameActive = active;
        if (active && Match is null)
            @Match = LiveMatch();
    }

    /**
     * Return whether the game logic should be running.
     * Currently, it implies that Bingo is active and that the current phase is not 'Starting' or
     * 'Ended'.
     */
    bool IsBingoPlaying() {
        if (!IsBingoActive())
            return false;

        GamePhase phase = GetPhase();
        return phase != GamePhase::Starting && phase != GamePhase::Ended;
    }

    /**
     * Return the match UID.
     */
    string GetMatchId() { return Match.uid; }

    /**
     * Set the match UID.
     * If the match UID is set, the plugin will try to reconnect to that match.
     */
    void SetMatchId(const string& in uid) {
        Match.uid = uid;

        PersistantStorage::LastConnectedMatchId = uid;
        Meta::SaveSettings();
    }

    /**
     * Unset the match UID.
     * This also has the effect of disabling reconnection.
     */
    void ClearMatchId() {
        if (Match !is null)
            Match.uid = "";
        PersistantStorage::ResetConnectedMatch();
    }

    /**
     * Get the game configuration.
     */
    MatchConfiguration @GetConfiguration() { return Match.config; }

    /**
     * Apply changes to the match configuration.
     */
    void SetConfiguration(MatchConfiguration config) {
        Match.config = config;
        InitializeTiles();
    }

    /**
     * Return the GameTime when the match will transitition to the play phase.
     */
    int64 GetStartTime() { return Match.startTime; }

    /**
     * Set the game to transition to the play phase at the specified GameTime.
     */
    void SetStartTime(int64 gameTime) { Match.startTime = gameTime; }

    /**
     * Ensure the size of the interal Tiles array is at least the grid's total cell count.
     * Automatically called after the game configuration is changed.
     */
    void InitializeTiles() {
        uint gridCellCount = Match.config.gridSize * Match.config.gridSize;

        for (uint i = Match.tiles.Length; i < gridCellCount; i++) {
            Match.tiles.InsertLast(GameTile());
        }
    }

    /**
     * Get the total amount of tiles on the Bingo board.
     * The tiles should be initalized.
     */
    uint GetTileCount() {
        return Math::Min(Match.config.gridSize * Match.config.gridSize, Match.tiles.Length);
    }

    /**
     * Get the amount of tiles a team has claimed on the Bingo board.
     */
    uint GetTileCountForTeam(Team team) {
        uint count = 0;
        for (uint i = 0; i < GetTileCount(); i++) {
            GameTile @tile = Match.tiles[i];

            if (tile !is null && tile.IsClaimed() && tile.LeadingRun().player.team.id == team.id)
                count += 1;
        }

        return count;
    }

    /**
     * Get the tile located at the given coordinates on the Bingo grid.
     */
    GameTile @GetTileOnGrid(uint x, uint y) {
        uint gridSize = Match.config.gridSize;
        uint index = y * gridSize + x;

        return GetTileFromIndex(index);
    }

    /**
     * Get the tile with the given index on the Bingo grid.
     */
    GameTile @GetTileFromIndex(uint index) {
        if (index >= GetTileCount())
            return null;
        return Match.tiles[index];
    }

    /**
     * Get the active play phase.
     */
    GamePhase GetPhase() { return Match.phase; }

    /**
     * Set the active play phase.
     */
    void SetPhase(GamePhase phase) {
        GamePhase previous = Match.phase;
        Match.phase = phase;

        if (previous == GamePhase::Starting) {
            UIGameRoom::SwitchToPlayContext();
        }

        if (phase == GamePhase::Overtime) {
            Match.overtimeStartTime = Time::Now;
        }
    }

    /**
     * Get the local player's Bingo team.
     */
    Team @GetOwnTeam() {
        Player @self = Match.GetSelf();

        if (self is null) {
            return null;
        } else {
            return self.team;
        }
    }

    /**
     * Get the local player's team color.
     */
    vec3 GetOwnTeamColor() {
        Team @team = GetOwnTeam();

        return team is null ? vec3(.5, .5, .5) : team.color;
    }

    /**
     * Get the tile which the local player is currently playing.
     */
    GameTile @GetCurrentTile() { return Match.GetCurrentTile(); }

    /**
     * Return whether the current map has been internally flagged as 'broken'.
     */
    bool IsCurrentMapBroken() { return Match.currentTileInvalid; }

    /**
     * Flag the current map as 'broken', meaning something isn't right or we couldn't load it.
     */
    void FlagCurrentMapAsBroken() { Match.currentTileInvalid = true; }

    /**
     * Get the current tile's index on the Bingo board. It identifies the map we're playing.
     * Can be an invalid index if we're not in a map.
     */
    int GetCurrentTileIndex() { return Match.currentTileIndex; }

    /**
     * Sets the index of the tile we are playing on the Bingo board.
     * -1 should represent that we are not in a map.
     */
    void SetCurrentTileIndex(int tileIndex) {
        Match.currentTileIndex = tileIndex;

        GameUpdates::MapIsCompetitivePatched = false;
        GameUpdates::ManialinkInitialized = false;
    }

    /**
     * Get the objective time to beat on the current map.
     */
    RunResult @GetObjectiveTimeToBeat() { return Playground::GetCurrentTimeToBeat(); }

    /**
     * Get the baseline time to reach to register a claim on the current map.
     */
    RunResult @GetBaselineTimeToBeat() { return Playground::GetCurrentTimeToBeat(true); }

    /**
     * Set the GameMap corresponding to the specified tile index.
     */
    void TileSetMap(uint tileIndex, GameMap map) {
        GameTile @tile = Match.tiles[tileIndex];
        tile.SetMap(map);

        // The map is changed, we are no longer on that tile
        if (int(tileIndex) == Match.currentTileIndex)
            Match.SetCurrentTileIndex(-1);
    }

    /**
     * Return whether the local player is in jail.
     */
    bool IsInJail() {
        return @Jail !is null;
    }

    /**
     * Stop the current game and close the connection.
     */
    void Shutdown() {
        // this is rudimentary, it doesn't keep connection alive
        trace("[Gamemaster::Shutdown] Closing the game.");
        ResetAll();
        Network::CloseConnection();
    }

    /**
     * Reset the game state to the initial state.
     */
    void ResetAll() {
        SetBingoActive(false);
        ClearMatchId();
        @Match = null;
        @Room = null;
        Playground::SetMapLeaderboardVisible(true);
        UIChat::ClearHistory();
        UIPoll::ClearAllPollsAndNotifications();
    }

    /**
     * Call game end handlers.
     */
    void HandleGameEnd() {
        UIPoll::ClearAllPollsAndNotifications();
        PersistantStorage::ResetConnectedMatch();

        // Remove all special tile states, except rainbow
        for (uint i = 0; i < GetTileCount(); i++) {
            if (Match.tiles[i] !is null && Match.tiles[i].specialState != TileItemState::Rainbow) {
                Match.tiles[i].specialState = TileItemState::Empty;
            }
        }
        // Disable jail
        @Jail = null;
        // Restore map leaderboards for competitive patch
        Playground::SetMapLeaderboardVisible(true);
    }
}
