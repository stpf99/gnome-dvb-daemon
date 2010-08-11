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

namespace Main {

    private static weak DVB.Manager manager;
    private static DVB.RecordingsStore recstore;
    private static bool has_debug;
    private static bool has_version;
    private static bool disable_epg_scanner;
    private static bool disable_rygel;
    private static bool enable_mediaserver2;
    private static MainLoop mainloop;

    const OptionEntry[] options =  {
        { "debug", 'd', 0, OptionArg.NONE, out has_debug,
        "Display debug statements on stdout", null},
        { "version", 0, 0, OptionArg.NONE, out has_version,
        "Display version number", null},
        { "disable-epg-scanner", 0, 0, OptionArg.NONE,
        out disable_epg_scanner, "Disable scanning for EPG data", null},
        { "disable-rygel", 0, 0, OptionArg.NONE,
        out disable_rygel, "Disable exporting devices and channels for Rygel", null},
        { "enable-mediaserver2", 0 ,0, OptionArg.NONE, out enable_mediaserver2,
        "Export devices and channels according to Rygel's MediaServer2 specification",
        null},
        { null }
    };
    
    private static bool start_manager () {
        try {
            var conn = DBus.Bus.get (DBus.BusType.SESSION);
            
            dynamic DBus.Object bus = conn.get_object (
                    "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus");
            
            // try to register service in session bus
            uint request_name_result = bus.RequestName (DVB.Constants.DBUS_SERVICE, (uint) 0);

            if (request_name_result == DBus.RequestNameReply.PRIMARY_OWNER) {
                message ("Creating new Manager D-Bus service");
            
                manager = DVB.Manager.get_instance ();
                                
                conn.register_object (
                    DVB.Constants.DBUS_MANAGER_PATH,
                    manager);
            } else {
                warning ("Manager D-Bus service is already running");
                return false;
            }

        } catch (Error e) {
            critical ("Oops %s", e.message);
            return false;
        }
        
        return true;
    }
    
    private static bool start_recordings_store () {
       message ("Creating new RecordingsStore D-Bus service");
       
       try {
            var conn = DBus.Bus.get (DBus.BusType.SESSION);
        
            recstore = DVB.RecordingsStore.get_instance ();
                            
            conn.register_object (
                DVB.Constants.DBUS_RECORDINGS_STORE_PATH,
                recstore);
        } catch (Error e) {
            critical ("Oops %s", e.message);
            return false;
        }
        
        return true;
    }
    
    private static void on_exit (int signum) {
        message ("Exiting");
        
        DVB.RTSPServer.shutdown ();
        DVB.Manager.shutdown ();
        DVB.Factory.shutdown ();
        DVB.RecordingsStore.shutdown ();
        
        recstore = null;
        manager = null;
        
        mainloop.quit ();
    }
    
    private static void log_func (string? log_domain, LogLevelFlags log_levels,
            string message) {
        if (has_debug)
            cUtils.log_default_handler (log_domain, log_levels, message, null);
    }
    
    public static bool get_disable_epg_scanner () {
        return Main.disable_epg_scanner;
    }

    private static bool check_feature_version (string name, uint major,
            uint minor, uint micro) {
        Gst.Registry reg = Gst.Registry.get_default ();
        Gst.PluginFeature feature = reg.lookup_feature (name);
        bool ret;
        if (feature == null)
            ret = false;
        else
            ret = feature.check_version (major, minor, micro);
        debug ("Has %s >= %u.%u.%u: %s", name, major, minor, micro, ret.to_string ());
        return ret;
    }

    private static bool check_requirements () {
        bool val;
        val = check_feature_version ("dvbsrc", 0, 10, 13);
        if (!val) return false;

        val = check_feature_version ("dvbbasebin", 0, 10, 13);
        if (!val) return false;

        val = check_feature_version ("mpegtsparse", 0, 10, 13);
        if (!val) return false;

        val = check_feature_version ("rtpmp2tpay", 0, 10, 14);
        return val;
    }

    private static void restore_device_groups () {
        DVB.database.ConfigStore config_store = DVB.Factory.get_config_store ();
        
        Gee.List<DVB.DeviceGroup> device_groups;
        try {
            device_groups = config_store.get_all_device_groups ();
        } catch (DVB.database.SqlError e) {
            critical ("%s", e.message);
            return;
        }

        message ("Restoring %d device groups", device_groups.size);
        foreach (DVB.DeviceGroup device_group in device_groups) {
            manager.restore_device_group_and_timers (device_group);
        }
    }
    
    public static int main (string[] args) {
        // set timezone to avoid that strftime stats /etc/localtime on every call
        Environment.set_variable ("TZ", "/etc/localtime", false);

        cUtils.Signal.connect (cUtils.Signal.SIGINT, on_exit);
        cUtils.Signal.connect (cUtils.Signal.SIGTERM, on_exit);
    
        OptionContext context = new OptionContext ("- record and watch TV shows using one or more DVB adapters");
        context.add_main_entries (options, null);
        context.add_group (Gst.init_get_option_group ());
        
        try {
            context.parse (ref args);
        } catch (OptionError e) {
            stderr.printf ("%s\n", e.message);
            stderr.printf ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
            return 1;
        }
        
        if (has_version) {
            stdout.printf (Config.PACKAGE_NAME);
            stdout.printf (" %s\n", Config.PACKAGE_VERSION);
            return 0;
        }
        
        Log.set_handler (null, LogLevelFlags.LEVEL_DEBUG |
            LogLevelFlags.FLAG_FATAL | LogLevelFlags.FLAG_RECURSION,
            log_func);
        
        // Creating a GLib main loop with a default context
        mainloop = new MainLoop (null, false);

        // Initializing GStreamer
        Gst.init (ref args);

        if (!check_requirements ()) {
            stderr.printf ("You don't have all of the necessary requirements to run %s.\n",
                Config.PACKAGE_NAME);
            stderr.printf ("Start the daemon with the --debug flag for more details.\n");
            return -1;
        }
        
        if (!start_manager ()) return -1;

        if (!start_recordings_store ()) return -1;
        
        restore_device_groups ();

        Idle.add (DVB.RTSPServer.start);

        if (!disable_rygel) {
            if (enable_mediaserver2)
                Idle.add (DVB.MediaServer2.start_rygel_services);
            else
                Idle.add (DVB.MediaServer.start_rygel_services);
        }

        // Start GLib mainloop
        mainloop.run ();
        
        return 0;
    }

}
