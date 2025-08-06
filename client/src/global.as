// Local player profile
PlayerProfile @Profile;

// Global active room
GameRoom @Room;

// Global active match
LiveMatch @Match;

// Local room configuration
RoomConfiguration RoomConfig;

// Local match configuration
MatchConfiguration MatchConfig;

// Globally active polls
array<PollData @> Polls;

// Local cache of TrackmaniaExchange maps (for development use)
array<GameMap> MapCache;

// Templated teams for the team editor
array<Team @> TeamPresets;

// Jail tile for the local player
GameTile@ Jail;
