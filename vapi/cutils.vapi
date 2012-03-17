
namespace cUtils {

    [CCode (cname = "timegm", cheader_filename="time.h")]
    public static time_t timegm (GLib.Time tm);

    [CCode (cname = "gst_bus_add_watch_context", cheader_filename = "cstuff.h")]
    public static uint gst_bus_add_watch_context (Gst.Bus bus, Gst.BusFunc func, GLib.MainContext context);

    [CCode (cname = "program_log"), PrintfFormat]
    public static void log (...);

    [Compact]
    [CCode (cname = "struct net_adapter", cheader_filename = "cstuff.h", free_function = "net_adapter_free")]
    public class NetAdapter {
        public unowned string name;
        public unowned string address;
    }

    [CCode (cname = "get_adapters", cheader_filename = "cstuff.h")]
    public GLib.List<NetAdapter?> get_adapters ();

}
