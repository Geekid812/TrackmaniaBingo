namespace Settings {
    // Network configuration for one backend.
    class BackendConfiguration {
        string NetworkAddress;
        uint16 TcpPort;
        uint16 HttpPort;
        bool HttpSecure;

        BackendConfiguration() {}
        BackendConfiguration(const string&in networkAddress, uint16 tcpPort, uint16 httpPort, bool httpSecure) {
            this.NetworkAddress = networkAddress;
            this.TcpPort = tcpPort;
            this.HttpPort = httpPort;
            this.HttpSecure = httpSecure;
        }
    }

    BackendConfiguration LOCALHOST_BACKEND = BackendConfiguration("localhost", 43333, 8080, false);
    BackendConfiguration LIVE_BACKEND = BackendConfiguration("38.242.214.20", 3085, 8085, true);

    enum BackendSelection {
        LocalDevelopment,
        Live,
        Custom
    }

    [Setting name="Selected Backend" category="Network"]
    BackendSelection Backend = BackendSelection::Live;

    [Setting name="Server Address" category="Custom Backend"]
    string CustomBackendAddress = "0.0.0.0";

    [Setting name="TCP Port" category="Custom Backend"]
    uint16 CustomNetworkPort = 3085;

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

    // Gets the active backend configuration.
    BackendConfiguration@ GetBackendConfiguration() {
        switch (Backend) {
            case BackendSelection::Live:
                return LIVE_BACKEND;
            case BackendSelection::LocalDevelopment:
                return LOCALHOST_BACKEND;
            default:
                return BackendConfiguration(CustomBackendAddress, CustomNetworkPort, CustomHttpPort, CustomHttpSecure);
        }
    }

    // Gets the HTTP scheme for the backend configuration.
    string HttpScheme(BackendConfiguration@ backend) {
        return backend.HttpSecure ? "https://" : "http://";
    }
}
