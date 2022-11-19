namespace Settings {
    [Setting name="Backend Server URL" category="Debug"]
    string BackendURL = "weathered-wind-9879.fly.dev";

    [Setting name="Backend TCP Port" category="Debug"]
    uint16 TcpPort = 6600;

    [Setting name="Backend HTTP Port" category="Debug"]
    uint16 HttpPort = 80;
    
    [Setting name="Connection Timeout" category="Debug"]
    uint ConnectionTimeout = 5000;

    [Setting name="Developer Mode" category="Debug"]
    bool DevMode = true;
}