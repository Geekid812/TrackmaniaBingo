
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

        req.Start();
        while (!req.Finished()) yield();

        int responseCode = req.ResponseCode();
        string responseBody = req.String();
        trace(tostring(req.Method).ToUpper() + " " + path + " " + responseCode + " " + Extra::IO::FormatFileSize(responseBody.Length));

        if (!HandleResponseCode(responseCode, req.Error(), responseBody)) return null;
        return req;
    }

    /**
     * Convenience function to receive a JSON body from an API request. It wraps the generic MakeRequest() method.
     */
    Json::Value@ MakeRequestJson(Net::HttpMethod method, const string&in path, const string&in body = "") {
        auto response = MakeRequest(method, path, body);
        if (response is null) return null;

        return response.Json();
    }

    bool HandleResponseCode(int responseCode, const string&in error, const string&in body) {
        if (responseCode == 0) {
            RaiseErrorMessage("Connection Error", "Communication with the server failed:\n" + error + "\n\nPlease check your connection!");
            return false;
        }

        if (responseCode >= 400) {
            if (responseCode < 500) {
                Json::Value@ bodyJson;
                try { bodyJson = Json::Parse(body); } catch {}

                string errorMessage = "The plugin encountered an error in a network request";

                if (bodyJson !is null && bodyJson.HasKey("detail")) {
                    errorMessage = tostring(bodyJson["detail"]);
                }

                RaiseErrorMessage("Plugin Error", "The plugin encountered an unexpected error. Please report this!\n" + responseCode + ": " + errorMessage);
            } else {
                RaiseErrorMessage("Server Error", "The Bingo server has encountered an unexpected error. Please report this!\n" + responseCode + ": " + body);
            }

            return false;
        }

        // Other non-error status codes, should be all good!
        return true;
    }
    
    void RaiseErrorMessage(const string&in title, const string&in message) {
        error("[API] " + title + ": " + message.Replace("\n", " | "));
        UI::ShowNotification(Icons::TimesCircle + " " + title, message, vec4(.9, .2, .2, .9), 15000);
    }
}
