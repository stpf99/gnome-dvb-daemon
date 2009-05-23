/*
 * Copyright (C) 2008,2009 Sebastian Pölsterl
 *
 * This file is part of GNOME DVB Daemon.
 *
 * GNOME DVB Daemon is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * GNOME DVB Daemon is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;

namespace DVB.Utils {

    private const int BUFFER_SIZE = 4096;

    public static unowned string? get_nick_from_enum (GLib.Type enumtype, int val) {
        EnumClass eclass = (EnumClass)enumtype.class_ref ();
        unowned EnumValue eval = eclass.get_value (val);
        
        if (eval == null) {
            critical ("Enum has no value %d", val);
            return null;
        } else {
            return eval.value_nick;
        }
    }
    
    public static bool get_value_by_name_from_enum (GLib.Type enumtype, string name, out int evalue) {
        EnumClass enumclass = (EnumClass)enumtype.class_ref ();
        unowned EnumValue eval = enumclass.get_value_by_name (name);
        
        if (eval == null) {
            critical ("Enum has no member named %s", name);
            return false;
        } else {
            evalue = eval.value;
            return true;
        }
    }
    
    public static unowned string? get_name_by_value_from_enum (GLib.Type enumtype, int val) {
        EnumClass enumclass = (EnumClass)enumtype.class_ref ();
        unowned EnumValue eval = enumclass.get_value (val);
        
        if (eval == null) {
            critical ("Enum has no value %d", val);
            return null;
        } else {
            return eval.value_name;
        }
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
            error ("RegexError: %s", e.message);
            return text;
        }
        
        string new_text;
        try {
            new_text = regex.replace_literal (text, text.size(), 0, "_", 0);
        } catch (RegexError e) {
            error ("RegexError: %s", e.message);
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
    
    /**
     * Creates Time of local time
     */
    public static Time create_time (int year, int month, int day, int hour,
        int minute, int second=0) {
        
        assert (year >= 1900 && month >= 1 && day >= 1 && hour >= 0 && minute >= 0
            && second >= 0);
        
        // Create Time with some initial value, otherwise time is wrong
        var t = Time.local (time_t ());
        
        t.year = year - 1900;
        t.month = month - 1;
        t.day = day;
        t.hour = hour;
        t.minute = minute;
        t.second = second;
        
        return t;
    }
    
    /**
     * Creates Time of UTC time
     */
    public static Time create_utc_time (int year, int month, int day, int hour,
        int minute, int second=0) {
        
        assert (year >= 1900 && month >= 1 && day >= 1 && hour >= 0 && minute >= 0
            && second >= 0);
        
        // Create Time with some initial value, otherwise time is wrong
        var t = Time.gm (time_t ());
        
        t.year = year - 1900;
        t.month = month - 1;
        t.day = day;
        t.hour = hour;
        t.minute = minute;
        t.second = second;
        t.isdst = -1; // undefined
        
        return t;
    }
    
    // TODO throw error
    public static string? read_file_contents (File file) throws Error {
        string attrs = "%s,%s".printf (
            FILE_ATTRIBUTE_STANDARD_TYPE,
            FILE_ATTRIBUTE_ACCESS_CAN_READ);
        
        FileInfo info;
        try {
            info = file.query_info (attrs, 0, null);
        } catch (Error e) {
            critical ("Could not retrieve attributes: %s", e.message);
            return null;
        }
        
        if (info.get_file_type () != FileType.REGULAR) {
            critical ("%s is not a regular file", file.get_path ());
            return null;
        }
        
        if (!info.get_attribute_boolean (FILE_ATTRIBUTE_ACCESS_CAN_READ)) {
            critical ("Cannot read %s", file.get_path ());
            return null;
        }
        
        FileInputStream stream;
        try {
            stream = file.read (null);
        } catch (IOError e) {
            critical ("Could not read file: %s", e.message);
            return null;
        }
    
        StringBuilder sb = new StringBuilder ();               
        char[] buffer = new char[BUFFER_SIZE];
        
        long bytes_read;
        while ((bytes_read = stream.read (buffer, BUFFER_SIZE, null)) > 0) {
            for (int i=0; i<bytes_read; i++) {
                sb.append_c (buffer[i]);
            }
        }
        stream.close (null);
        
        return sb.str;
    }
    
    public static void delete_dir_recursively (File dir) throws Error {
        string attrs = "%s,%s".printf (FILE_ATTRIBUTE_STANDARD_TYPE,
                                       FILE_ATTRIBUTE_STANDARD_NAME);
    
        FileEnumerator files;
        files = dir.enumerate_children (attrs, 0, null);
        if (files == null) return;
        
        FileInfo childinfo;
        while ((childinfo = files.next_file (null)) != null) {
            uint32 type = childinfo.get_attribute_uint32 (
                FILE_ATTRIBUTE_STANDARD_TYPE);
            
            File child = dir.get_child (childinfo.get_name ());
        
            switch (type) {
                case FileType.DIRECTORY:
                delete_dir_recursively (child);
                break;
                
                case FileType.REGULAR:
                debug ("Deleting file %s", child.get_path ());
                child.delete (null);
                break;
            }
        }
        
        debug ("Deleting directory %s", dir.get_path ());
        dir.delete (null);
    }

    public static DBus.Connection? get_dbus_connection () {
        DBus.Connection conn;
        try {
            conn = DBus.Bus.get (DBus.BusType.SESSION);
        } catch (Error e) {
            error("Could not get D-Bus session bus: %s", e.message);
            return null;
        }
        return conn;
    }
        
}
