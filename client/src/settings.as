namespace Settings {
    // Network configuration for one backend.
    class BackendConfiguration {
        string NetworkAddress;
        uint16 TcpPort;

        BackendConfiguration() {}
        BackendConfiguration(const string&in networkAddress, uint16 tcpPort) {
            this.NetworkAddress = networkAddress;
            this.TcpPort = tcpPort;
        }
    }

    BackendConfiguration LOCALHOST_BACKEND = BackendConfiguration("localhost", 43333);
    BackendConfiguration LIVE_BACKEND = BackendConfiguration("vmi1095534.contaboserver.net", 43333);

    enum BackendSelection {
        LocalDevelopment,
        Live,
        Custom
    }

    [Setting name="Chat" category="Bindings"]
    VirtualKey ChatBindingKey = VirtualKey::Return;

    [Setting name="Toggle Map List" category="Bindings"]
    VirtualKey MaplistBindingKey = VirtualKey::Tab;

    [Setting name="Selected Backend" category="Developer"]
    BackendSelection Backend = BackendSelection::Live;

    [Setting name="Server Address" category="Custom Backend"]
    string CustomBackendAddress = "0.0.0.0";

    [Setting name="TCP Port" category="Custom Backend"]
    uint16 CustomNetworkPort = 3085;
    
    [Setting name="Connection Timeout" category="Developer"]
    uint NetworkTimeout = 10000;

    [Setting name="Server Ping Interval" category="Developer"]
    uint PingInterval = 30000;

    [Setting name="Enable Developer Tools" category="Developer"]
    bool DevTools = false;

    // Gets the active backend configuration.
    BackendConfiguration@ GetBackendConfiguration() {
        switch (Backend) {
            case BackendSelection::Live:
                return LIVE_BACKEND;
            case BackendSelection::LocalDevelopment:
                return LOCALHOST_BACKEND;
            default:
                return BackendConfiguration(CustomBackendAddress, CustomNetworkPort);
        }
    }
}
