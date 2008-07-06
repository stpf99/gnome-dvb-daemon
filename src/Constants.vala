using GLib;

namespace DVB.Constants {

    public static const string DBUS_SERVICE = "org.gnome.DVB";
    
    public static const string DBUS_MANAGER_PATH = "/org/gnome/DVB/Manager";
    public static const string DBUS_RECORDINGS_STORE_PATH = "/org/gnome/DVB/RecordingsStore";
    public static const string DBUS_SCANNER_PATH = "/org/gnome/DVB/Scanner/%d/%d";
    public static const string DBUS_RECORDER_PATH = "/org/gnome/DVB/Recorder/%d/%d";
    public static const string DBUS_CHANNEL_LIST_PATH = "/org/gnome/DVB/ChannelList/%d/%d";
}
