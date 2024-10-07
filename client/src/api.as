
namespace API {

    /**
     * Generic coroutine for API calls. Handles all network errors in a generic pattern.
     * Returns a null pointer if the request did not succeed.
     */
    Net::HttpRequest@ MakeRequest(Net::HttpMethod method, const string&in path, const string&in body = "") {
        Settings::BackendConfiguration backend = Settings::GetBackendConfiguration();

        string url = Settings::HttpScheme(backend) + backend.NetworkAddress + ":" + backend.HttpPort + path;

        Net::HttpRequest req();
        req.Method = method;
        req.Url = url;
        req.Body = body;
        req.Headers = {
            {"content-type", "application/json"}
        };

        string token = PersistantStorage::ClientToken;
        if (token != "") {
            req.Headers.Set("x-token", token);
        }

        req.Start();
        while (!req.Finished()) yield();

        int responseCode = req.ResponseCode();
        string responseBody = req.String();
        trace("[API] " + tostring(req.Method).ToUpper() + " " + path + " " + responseCode + " " + IOExtra::FormatFileSize(responseBody.Length));
        
        if (Settings::Verbose) {
            trace("[API] " + responseBody);
        }

        return HandleResponse(req);
    }

    /**
     * Convenience function to receive a JSON body from an API request. It wraps the generic MakeRequest() method.
     */
    Json::Value@ MakeRequestJson(Net::HttpMethod method, const string&in path, const string&in body = "") {
        auto response = MakeRequest(method, path, body);
        if (response is null) return null;

        return response.Json();
    }

    Net::HttpRequest@ HandleResponse(Net::HttpRequest@ req) {
        int responseCode = req.ResponseCode();
        if (responseCode == 0) {
            RaiseErrorMessage("Connection Error", "Communication with the server failed:\n" + req.Error() + "\n\nPlease check your connection!");
            return null;
        }

        if (responseCode >= 400) {
            if (responseCode == 403 || responseCode == 401) {
                // Note: this could cycle if Login returned a 401/403 error (this is currently not possible)
                warn("[API] Handling " + ( responseCode == 401 ? "HTTP_401_UNAUTHORIZED" : "HTTP_403_FORBIDDEN") + " request silently: attempting login.");
                Login::Login();
                return null;
            }

            string body = req.String();
            if (responseCode < 500) {
                Json::Value@ bodyJson;
                try { @bodyJson = Json::Parse(body); } catch {}

                string errorMessage = "The plugin encountered an error in a network request";

                if (bodyJson !is null && bodyJson.HasKey("detail")) {
                    errorMessage = Json::Write(bodyJson["detail"]);
                }

                RaiseErrorMessage("Plugin Error", "The plugin encountered an unexpected error. Please report this!\n\n" + responseCode + ": " + errorMessage);
            } else {
                RaiseErrorMessage("Server Error", "The Bingo server has encountered an unexpected error. Please report this!\n\n" + responseCode + ": " + body);
            }

            return null;
        }

        // Other non-error status codes, should be all good!
        return req;
    }
    
    void RaiseErrorMessage(const string&in title, const string&in message) {
        error("[API] " + title + ": " + message);
        UI::ShowNotification(Icons::TimesCircle + " " + title, message, vec4(.9, .2, .2, .9), 20000);
    }
}
