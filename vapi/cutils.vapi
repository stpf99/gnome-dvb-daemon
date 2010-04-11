
namespace cUtils {

    [CCode (cname = "timegm", cheader_filename="time.h")]
    public static time_t timegm (GLib.Time tm);
    
    [CCode (cheader_filename = "signal.h")]
    namespace Signal {
        [CCode (cname = "SIGINT")]
        public static const int SIGINT;
        [CCode (cname = "SIGHILL")]
        public static const int SIGHILL;
        [CCode (cname = "SIGABRT")]
        public static const int SIGABRT;
        [CCode (cname = "SIGFPE")]
        public static const int SIGFPE;
        [CCode (cname = "SIGSEGV")]
        public static const int SIGSEGV;
        [CCode (cname = "SIGTERM")]
        public static const int SIGTERM;
        
        [CCode (has_target = false)]
        public delegate void SignalHandler (int signum);
        
        [CCode (cname="signal")]
        public static SignalHandler connect (int signum, SignalHandler handler);
    }

    [CCode (cname = "g_log_default_handler", cheader_filename = "glib.h")]
    public static void log_default_handler (string? log_domain, GLib.LogLevelFlags log_levels, string message, void* data);

    [CCode (cname = "gst_bus_add_watch_context", cheader_filename = "cstuff.h")]
    public static uint gst_bus_add_watch_context (Gst.Bus bus, Gst.BusFunc func, GLib.MainContext context);

    [CCode (cname = "program_log"), PrintfFormat]
    public static void log (...);

}
