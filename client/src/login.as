
namespace Login {

    void EnsureLoggedIn() {
        if (!IsLoggedIn()) {
            print("[Login::EnsureLoggedIn] No client token in store, attempting to authenticate.");
            Login();
        } else {
            trace("[Login::EnsureLoggedIn] Client is logged in.");
        }
    }

    bool IsLoggedIn() {
        return PersistantStorage::ClientToken != "";
    }

    void Login() {
#if TURBO
        throw("Login() called on Turbo! This is invalid.");
#else
        trace("[Login] Fetching a new authentication token...");
        string authToken;
        string authenticationMethod = "Openplanet";
        try {
            authToken = FetchAuthToken();

            if (authToken != "") {
                trace("[Login] Received new authentication token.");
            } else {
                err("Login", "Failed to authenticate with the Openplanet servers. Please check for connection issues.");
                return;
            }
        } catch {
            print("[Login] Openplanet authentication unavailable: " + getExceptionInfo());
            print("[Login] Falling back to basic authentication.");
            authenticationMethod = "None";
        }

        Settings::BackendConfiguration backend = Settings::GetBackendConfiguration();
        trace("[Login] Attempting to login to " + backend.NetworkAddress + "...");
        string url = Settings::HttpScheme(backend) + backend.NetworkAddress + ":" + backend.HttpPort + "/auth/login";

        Json::Value@ body = Json::Object();
        body["authentication"] = authenticationMethod;
        body["account_id"] = GetAccountId();
        body["display_name"] = GetLocalUsername();
        if (authenticationMethod == "Openplanet") body["token"] = authToken;

        auto req = Net::HttpRequest();
        req.Url = url;
        req.Method = Net::HttpMethod::Post;
        req.Body = Json::Write(body);
        req.Headers = {
            {"content-type", "application/json"}
        };
        req.Start();

        while (!req.Finished()) { yield(); }
        if (Extra::Net::RequestRaiseError("Login", req)) {
            int status = req.ResponseCode();
            err("Login", "Failed to login with the game server: " + req.String() + " (Error " + status + ")");
        
            if (status == 503) {
                errnote("Error 503 indicates an issue with Openplanet authentication servers. Try again later if possible!");
            }
            return;
        }

        PersistantStorage::ClientToken = req.String();
        trace("[Login] Success.");
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
