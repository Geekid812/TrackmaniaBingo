
namespace User {
    /*
     * Get the local player's username.
     */
    string GetLocalUsername() {
        auto network = cast<CTrackManiaNetwork>(GetApp().Network);
        return network.PlayerInfo.Name;
    }

    /*
     * Get the local player's webservices account ID.
     */
    string GetAccountId() {
        auto network = cast<CTrackManiaNetwork>(GetApp().Network);
        return network.PlayerInfo.WebServicesUserId;
    }
}
