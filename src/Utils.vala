using GLib;

namespace DVB.Utils {

    public static weak string get_nick_from_enum (GLib.Type enumtype, int val) {
        EnumClass eclass = (EnumClass)enumtype.class_ref();
        return eclass.get_value(val).value_nick;
    }
    
    public static weak int get_value_by_name_from_enum (GLib.Type enumtype, string name) {
        EnumClass enumclass = (EnumClass)enumtype.class_ref ();
        return enumclass.get_value_by_name(name).value;
    }
    
    public static weak string get_name_by_value_from_enum (GLib.Type enumtype, int val) {
        EnumClass enumclass = (EnumClass)enumtype.class_ref ();
        return enumclass.get_value(val).value_name;
    }
    
    public static void mkdirs (File directory) throws Error {
        SList<File> create_dirs = new SList<File> ();
        
        File current_dir = directory;
        while (current_dir != null) {
            if (current_dir.query_exists (null)) break;
            create_dirs.prepend (current_dir);
            current_dir = current_dir.get_parent ();
        }
        
        foreach (File dir in create_dirs) {
            debug ("Creating %s", dir.get_path ());
            dir.make_directory (null);
        }
    }
    
    public static string remove_nonalphanums (string text) {
        Regex regex;
        try {
            regex = new Regex ("\\W", 0, 0);
        } catch (RegexError e) {
            error (e.message);
            return text;
        }
        
        string new_text;
        try {
            new_text = regex.replace_literal (text, text.size(), 0, "_", 0);
        } catch (RegexError e) {
            error (e.message);
            return text;
        }
        
        return new_text;
    }
    
    /**
     * @returns: Difference in seconds
     */ 
    public static int64 difftime (Time t1, Time t2) {
        int64 ts1 = (int64)t1.mktime ();
        int64 ts2 = (int64)t2.mktime ();
        
        int64 diff = ts1 - ts2;
        if (diff < 0) return -1*diff;
        else return diff;
    }
    
    public static Time create_time (int year, int month, int day, int hour, int minute) {
        // Create Time with some initial value, otherwise time is wrong
        var t = Time.local (time_t ());
        
        t.year = year - 1900;
        t.month = month - 1;
        t.day = day;
        t.hour = hour;
        t.minute = minute;
        
        return t;
    }

}
