using GLib;

namespace DVB.Constants {

    public static const string DBUS_SERVICE = "org.gnome.DVB";
    
    public static const string DBUS_MANAGER_PATH = "/org/gnome/DVB/Manager";
    public static const string DBUS_RECORDINGS_STORE_PATH = "/org/gnome/DVB/RecordingsStore";
    public static const string DBUS_SCANNER_PATH = "/org/gnome/DVB/Scanner/%d/%d";
    public static const string DBUS_RECORDER_PATH = "/org/gnome/DVB/Recorder/%u";
    public static const string DBUS_CHANNEL_LIST_PATH = "/org/gnome/DVB/ChannelList/%u";
    public static const string DBUS_SCHEDULE_PATH = "/org/gnome/DVB/Schedule/%u/%u";
    public static const string DVB_DEVICE_PATH = "/dev/dvb/adapter%u/frontend%u";
}
