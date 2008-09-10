
namespace cUtils {

    [CCode (cname = "timegm", cheader_filename="time.h")]
    public static time_t timegm (GLib.Time tm);

}
