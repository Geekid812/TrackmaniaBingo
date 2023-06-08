#!/bin/bash
cat mapcache.service | sed "s+{SCRIPT_PATH}+$PWD+g" > ~/.config/systemd/user/mapcache.service
cp -f mapcache.timer ~/.config/systemd/user/mapcache.timer
systemctl --user daemon-reload
systemctl --user start mapcache.timer
echo "mapcache service installed and started."
