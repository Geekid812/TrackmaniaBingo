
string GetLocalUsername() {
#if TMNEXT
    return GetLocalLogin();
#elif TURBO
    auto localInfo = GetApp().Network.PlaygroundInterfaceScriptHandler.LocalPlayerInfo;
    return localInfo.Name;
#endif
}