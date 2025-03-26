
namespace Login {

    string GetExchangeToken() {
        trace("[Login] Getting a new authentication token...");
        string authToken;
        try {
            authToken = FetchAuthToken();

            if (authToken != "") {
                trace("[Login] Received new authentication token.");
            } else {
                err("Login",
                    "Failed to authenticate with the Openplanet servers. Please check for "
                    "connection issues.");
            }
        } catch {
            print("[Login] Openplanet authentication unavailable: " + getExceptionInfo());
            print("[Login] Falling back to basic authentication.");
            authToken = "";
        }

        return authToken;
    }

    string FetchAuthToken() {
        Auth::PluginAuthTask @task = Auth::GetToken();
        while (!task.Finished()) {
            yield();
        }
        return task.Token();
    }
}
