
namespace Login {

    void EnsureLoggedIn() {
        if (!IsLoggedIn()) {
            print("Login: No client token in store, attempting to authenticate.");
            Login();
        } else {
            trace("Login: Client is logged in.");
        }
    }

    bool IsLoggedIn() {
#if TURBO
        return true;
#else
        return PersistantStorage::ClientToken != "";
#endif
    }

    void Login() {
#if TURBO
        throw("Login() called on Turbo! This is invalid.");
#else
        trace("Auth: Fetching a new authentication token...");
        string authToken = FetchAuthToken();
        if (authToken != "") {
            trace("Auth: Received new authentication token.");
        } else {
            err("Auth", "Failed to authenticate with the Openplanet servers. Please check for connection issues.");
            return;
        }

        trace("Login: Attempting to login to " + Settings::BackendAddress + "...");
        string url = "http://" + Settings::BackendAddress + ":" + Settings::HttpPort + "/auth/login?token=" + Net::UrlEncode(authToken);
        auto req = Net::HttpGet(url);
        while (!req.Finished()) { yield(); }
    
        int status = req.ResponseCode();
        if (status != 200) {
            err("Login", "Failed to login with the game server: " + req.String() + " (Error " + status + ")");
            if (status == 0) {
                errnote("Error 0 indicates a network connection error. Please check your connection and configuration.");
            } else if (status == 503) {
                errnote("Error 503 indicates an issue with Openplanet authentication servers. Try again later if possible!");
            }
            return;
        }

        PersistantStorage::ClientToken = req.String();
        trace("Login: Success.");
#endif
    }

#if TMNEXT
    string FetchAuthToken() {
        Auth::PluginAuthTask@ task = Auth::GetToken();
        while (!task.Finished()) { yield(); }
        return task.Token();
    }
#endif
}
