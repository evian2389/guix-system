set +x

echo "Type your keyring password when prompted, then press Ctrl+D twice."
export $(dbus-launch)
gnome-keyring-daemon -r --unlock --components=secrets

