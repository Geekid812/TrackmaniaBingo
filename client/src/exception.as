
void err(const string&in ns, const string&in text) {
    error(ns + ": " + text);
    UI::ShowNotification("", Icons::ExclamationTriangle + " " + text, vec4(.8, .2, .2, 1.), 15000);
}

void errnote(const string&in text) {
    warn("Troubleshooter: " + text);
    UI::ShowNotification("", Icons::ExclamationCircle + " " + text, vec4(.8, .8, .2, 1.), 15000);
}

