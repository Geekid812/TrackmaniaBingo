
// Get the local player's username.
string GetLocalUsername() {
#if TMNEXT
    return GetLocalLogin();
#elif TURBO
    auto playground = GetApp().Network.PlaygroundInterfaceScriptHandler;
    if (playground is null) return "";
    return playground.LocalPlayerInfo.Name;
#endif
}

// Get the local player's webservices account ID.
string GetAccountId() {
    auto network = cast<CTrackManiaNetwork>(GetApp().Network);
    return network.PlayerInfo.WebServicesUserId;
}
