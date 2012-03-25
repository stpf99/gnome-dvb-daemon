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

    private const string NAME_ATTRS = FileAttribute.STANDARD_TYPE + "," + FileAttribute.STANDARD_NAME;
    private const string READ_ATTRS = FileAttribute.STANDARD_TYPE + "," + FileAttribute.ACCESS_CAN_READ;

    public static inline unowned string? get_nick_from_enum (GLib.Type enumtype, int val) {
        EnumClass eclass = (EnumClass)enumtype.class_ref ();
        unowned EnumValue? eval = eclass.get_value (val);

        if (eval == null) {
            Main.log.error ("Enum has no value %d", val);
            return null;
        } else {
            return eval.value_nick;
        }
    }

    public static inline bool get_value_by_name_from_enum (GLib.Type enumtype, string name, out int evalue) {
        EnumClass enumclass = (EnumClass)enumtype.class_ref ();
        unowned EnumValue? eval = enumclass.get_value_by_name (name);

        if (eval == null) {
            Main.log.error ("Enum has no member named %s", name);
            evalue = 0;
            return false;
        } else {
            evalue = eval.value;
            return true;
        }
    }

    public static inline unowned string? get_name_by_value_from_enum (GLib.Type enumtype, int val) {
        EnumClass enumclass = (EnumClass)enumtype.class_ref ();
        unowned EnumValue? eval = enumclass.get_value (val);

        if (eval == null) {
            Main.log.error ("Enum has no value %d", val);
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
            Main.log.debug ("Creating %s", dir.get_path ());
            dir.make_directory (null);
        }
    }

    public static string remove_nonalphanums (string text) {
        Regex regex;
        try {
            regex = new Regex ("[^-_\\.a-zA-Z0-9]", 0, 0);
        } catch (RegexError e) {
            Main.log.error ("RegexError: %s", e.message);
            return text;
        }

        string new_text;
        try {
            new_text = regex.replace_literal (text, -1, 0, "_", 0);
        } catch (RegexError e) {
            Main.log.error ("RegexError: %s", e.message);
            return text;
        }

        return new_text;
    }

    /**
     * @returns: Difference in seconds
     */
    public static inline time_t difftime (Time t1, Time t2) {
        time_t ts1 = t1.mktime ();
        time_t ts2 = t2.mktime ();

        time_t diff = ts1 - ts2;
        if (diff < 0) return -1*diff;
        else return diff;
    }

    /**
     * Creates Time of local time
     */
    public static inline Time create_time (int year, int month, int day, int hour,
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
    public static inline Time create_utc_time (int year, int month, int day, int hour,
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

    public static bool is_readable_file (File file) {
        FileInfo info;
        try {
            info = file.query_info (READ_ATTRS, 0, null);
        } catch (Error e) {
            Main.log.error ("Could not retrieve attributes: %s", e.message);
            return false;
        }

        if (info.get_file_type () != FileType.REGULAR) {
            Main.log.error ("%s is not a regular file", file.get_path ());
            return false;
        }

        if (!info.get_attribute_boolean (FileAttribute.ACCESS_CAN_READ)) {
            Main.log.error ("Cannot read %s", file.get_path ());
            return false;
        }

        return true;
    }

    public static void delete_dir_recursively (File dir) throws Error {
        FileEnumerator files;
        files = dir.enumerate_children (NAME_ATTRS, 0, null);
        if (files == null) return;

        FileInfo childinfo;
        while ((childinfo = files.next_file (null)) != null) {
            uint32 type = childinfo.get_attribute_uint32 (
                FileAttribute.STANDARD_TYPE);

            File child = dir.get_child (childinfo.get_name ());

            switch (type) {
                case FileType.DIRECTORY:
                delete_dir_recursively (child);
                break;

                case FileType.REGULAR:
                Main.log.debug ("Deleting file %s", child.get_path ());
                child.delete (null);
                break;
            }
        }

        Main.log.debug ("Deleting directory %s", dir.get_path ());
        dir.delete (null);
    }

    public static time_t t_max (time_t a, time_t b) {
        return (a < b) ? b : a;
    }

    public static time_t t_min (time_t a, time_t b) {
        return (a < b) ? a : b;
    }

    public static long strdiff (string a, string b, out long unmatched) {
        long len_a = a.length;
        long len_b = b.length;

        long max;
        if (len_a < len_b) {
            max = len_b;
            unmatched = len_b - len_a;
        } else {
            max = len_a;
            unmatched = len_a - len_b;
        }

        long diff = 0;
        for (int i=0; i<max; i++) {
            if (a.get (i) != b.get (i)) {
                diff++;
            }
        }

        return diff;
    }

    public static void dbus_own_name (string service_name, BusAcquiredCallback cb) {
        Main.log.info ("Creating D-Bus service %s", service_name);
        Bus.own_name (BusType.SESSION, service_name, BusNameOwnerFlags.NONE,
            cb,
            () => {},
            () => warning ("Could not acquire name"));
    }

    public static inline void dbus_register_object<T> (DBusConnection conn, string object_path, T obj) {
        try {
            conn.register_object (object_path, obj);
        } catch (IOError e) {
            Main.log.error ("Could not register object '%s': %s", object_path, e.message);
        }
    }

}
