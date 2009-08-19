/*
 * Copyright (C) 2009 Sebastian Pölsterl
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

namespace DVB {
    
    public class Settings : GLib.Object {
    
        public static const string TIMERS_SECTION = "timers";
        public static const string MARGIN_START = "margin_start";
        public static const string MARGIN_END = "margin_end";
        
        public static const string EPG_SECTION = "epg";
        public static const string SCAN_INTERVAL = "scan_interval";

        private static const string DEFAULT_SETTINGS =
        """[timers]
        margin_start=5
        margin_end=5
        [epg]
        scan_interval=30""";
        
        private KeyFile keyfile;

        construct {
            keyfile = new KeyFile ();
        }
        
        public File get_settings_file () {
            File config_dir = File.new_for_path (
                Environment.get_user_config_dir ());
            File our_config = config_dir.get_child ("gnome-dvb-daemon");
            File settings_file = our_config.get_child ("settings.ini");
            
            return settings_file;
        }
        
        public bool load () {
            File settings_file = this.get_settings_file ();
            bool success = true;
            if (!settings_file.query_exists (null)) {
                FileOutputStream stream = null;
                try {
                    stream = settings_file.create (0, null);
                } catch (Error e) {
                    critical ("Could not create file %s: %s",
                        settings_file.get_path (), e.message);
                    return false;
                }
                
                try {
                    stream.write (DEFAULT_SETTINGS, DEFAULT_SETTINGS.size(), null);
                } catch (Error e) {
                    critical ("Could not write to file %s: %s",
                        settings_file.get_path (), e.message);
                    success = false;
                }
                
                try {
                    stream.close (null);
                } catch (Error e) {
                    critical ("%s", e.message);
                    success = false;
                }
            }
            
            if (success) {
                try {
                    keyfile.load_from_file (settings_file.get_path (), 0);
                } catch (KeyFileError e) {
                    critical ("Could not load settings: %s", e.message);
                    success = false;
                } catch (FileError e) {
                    critical ("Could not load settings: %s", e.message);
                    success = false;
                }
            }
            
            return success;
        }
        
        public bool save () {
            File settings_file = this.get_settings_file ();
            
            FileOutputStream stream = null;
            try {
                stream = settings_file.replace (null, true, 0, null);
            } catch (Error e) {
                critical ("Could not replace file %s: %s",
                    settings_file.get_path (), e.message);
                return false;
            }
            
            string data = null;
            size_t data_len;
            data = this.keyfile.to_data (out data_len);
                
            try {
                stream.write_all (data, data_len, null, null);
            } catch (Error e) {
                critical ("Could not write to file %s: %s",
                    settings_file.get_path (), e.message);
                return false;
            }
                
            
            try {
                stream.close (null);
            } catch (Error e) {
                critical ("%s", e.message);
            }
        
            return false;
        }
        
        public string get_string (string group_name, string key) throws KeyFileError {
            return this.keyfile.get_string (group_name, key);
        }
        
        public bool get_boolean (string group_name, string key) throws KeyFileError {
            return this.keyfile.get_boolean (group_name, key);
        }
        
        public int get_integer (string group_name, string key) throws KeyFileError {
            return this.keyfile.get_integer (group_name, key);
        }
        
        public double get_double (string group_name, string key) throws KeyFileError {
            return this.keyfile.get_double (group_name, key);
        }
        
        public string[] get_string_list (string group_name, string key) throws KeyFileError {
            return this.keyfile.get_string_list (group_name, key);
        }
        
        public bool[] get_boolean_list (string group_name, string key) throws KeyFileError {
            return this.keyfile.get_boolean_list (group_name, key);
        }
        
        public int[] get_integer_list (string group_name, string key) throws KeyFileError {
            return this.keyfile.get_integer_list (group_name, key);
        }
        
        public double[] get_double_list (string group_name, string key) throws KeyFileError {
            return this.keyfile.get_double_list (group_name, key);
        }
        
        public void set_string (string group_name, string key, string val) throws KeyFileError {
            this.keyfile.set_string (group_name, key, val);
        }
        
        public void set_boolean (string group_name, string key, bool val) throws KeyFileError {
            this.keyfile.set_boolean (group_name, key, val);
        }
        
        public void set_double (string group_name, string key, double val) throws KeyFileError {
            this.keyfile.set_double (group_name, key, val);
        }
        
        public void set_integer (string group_name, string key, int val) throws KeyFileError {
            this.keyfile.set_integer (group_name, key, val);
        }
        
        public void set_string_list (string group_name, string key, string[] val) throws KeyFileError {
            this.keyfile.set_string_list (group_name, key, val);
        }
        
        public void set_boolean_list (string group_name, string key, bool[] val) throws KeyFileError {
            this.keyfile.set_boolean_list (group_name, key, val);
        }

        public void set_double_list (string group_name, string key, double[] val) throws KeyFileError {
            this.keyfile.set_double_list (group_name, key, val);
        }
        
        public void set_integer_list (string group_name, string key, int[] val) throws KeyFileError {
            this.keyfile.set_integer_list (group_name, key, val);
        }
        
    }

}
