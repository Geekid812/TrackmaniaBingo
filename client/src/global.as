// Local player profile
PlayerProfile@ Profile;

// Global active room
GameRoom@ Room;

// Global active match
LiveMatch@ Match;

// Local room configuration
ChannelConfiguration RoomConfig;

// Local game configuration
GameRules GameConfig;

// Globally active polls
array<PollData@> Polls;

// Local cache of TrackmaniaExchange maps (for development use)
array<GameMap> MapCache;
