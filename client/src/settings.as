namespace Settings {
    // Network configuration for one backend.
    class BackendConfiguration {
        string NetworkAddress;
        uint16 HttpPort;
        bool HttpSecure;

        BackendConfiguration() {}
        BackendConfiguration(const string&in networkAddress, uint16 httpPort, bool httpSecure) {
            this.NetworkAddress = networkAddress;
            this.HttpPort = httpPort;
            this.HttpSecure = httpSecure;
        }
    }

    BackendConfiguration LOCALHOST_BACKEND = BackendConfiguration("localhost", 8000, false);
    BackendConfiguration LIVE_BACKEND = BackendConfiguration("38.242.214.20", 8085, true);

    enum BackendSelection {
        LocalDevelopment,
        Live,
        Custom
    }

    [Setting name="Selected Backend" category="Network"]
    BackendSelection Backend = BackendSelection::Live;

    [Setting name="Server Address" category="Custom Backend"]
    string CustomBackendAddress = "0.0.0.0";

    [Setting name="HTTP Port" category="Custom Backend"]
    uint16 CustomHttpPort = 8085;

    [Setting name="Use HTTPS" category="Custom Backend"]
    bool CustomHttpSecure = false;
    
    [Setting name="Connection Timeout" category="Network"]
    uint NetworkTimeout = 10000;

    [Setting name="Server Ping Interval" category="Network"]
    uint PingInterval = 30000;

    [Setting name="Enable Developer Tools" category="Debug"]
    bool DevTools = false;

    [Setting name="Enable Verbose Logging" category="Debug"]
    bool Verbose = false;

    // Gets the active backend configuration.
    BackendConfiguration@ GetBackendConfiguration() {
        switch (Backend) {
            case BackendSelection::Live:
                return LIVE_BACKEND;
            case BackendSelection::LocalDevelopment:
                return LOCALHOST_BACKEND;
            default:
                return BackendConfiguration(CustomBackendAddress, CustomHttpPort, CustomHttpSecure);
        }
    }

    // Gets the HTTP scheme for the backend configuration.
    string HttpScheme(BackendConfiguration@ backend) {
        return backend.HttpSecure ? "https://" : "http://";
    }
}
