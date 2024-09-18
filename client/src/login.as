
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
        PersistantStorage::ClientToken = ""; // Clear previous token

        trace("[Login] Fetching a new authentication token...");
        string authToken;
        AuthenticationMethod authenticationMethod = AuthenticationMethod::Openplanet;
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
            authenticationMethod = AuthenticationMethod::None;
        }

        Settings::BackendConfiguration backend = Settings::GetBackendConfiguration();
        string hostname = Settings::HttpScheme(backend) + backend.NetworkAddress + ":" + backend.HttpPort;
        trace("[Login] Attempting to login to " + hostname + "...");

        Json::Value@ body = Json::Object();
        body["authentication"] = authenticationMethod;
        body["username"] = User::GetLocalUsername();
        body["account_id"] = User::GetAccountId();

        if (authenticationMethod == AuthenticationMethod::Openplanet) {
            body["token"] = authToken;
        }

        Json::Value@ res = API::MakeRequestJson(Net::HttpMethod::Post, "/auth/login", Json::Write(body));
        if (res is null) return;

        PersistantStorage::ClientToken = res["client_token"];

        string userIdent = string(res["name"]) + " (uid " + int(res["uid"]) + ")";
        trace("[Login] Success: Logged in as " + userIdent);
    }

#if TMNEXT
    string FetchAuthToken() {
        Auth::PluginAuthTask@ task = Auth::GetToken();
        while (!task.Finished()) { yield(); }
        return task.Token();
    }
#endif
}
