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

[Compact]
public class Main {

    private static weak DVB.Manager manager;
    private static DVB.RecordingsStore recstore;
    private static bool has_debug;
    private static bool has_version;
    private static bool disable_epg_scanner;
    private static MainLoop mainloop;
    private static Gst.RTSPServer server;

    const OptionEntry[] options =  {
        { "debug", 'd', 0, OptionArg.NONE, out has_debug,
        "Display debug statements on stdout", null},
        { "version", 0, 0, OptionArg.NONE, out has_version,
        "Display version number", null},
        { "disable-epg-scanner", 0, 0, OptionArg.NONE,
        out disable_epg_scanner, "Disable scanning for EPG data", null},
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
            error ("Oops %s", e.message);
            return false;
        }
        
        return true;
    }
    
    private static bool start_recordings_store (uint32 minimum_id) {
       message ("Creating new RecordingsStore D-Bus service");
       
       try {
            var conn = DBus.Bus.get (DBus.BusType.SESSION);
        
            recstore = DVB.RecordingsStore.get_instance ();
            recstore.update_last_id (minimum_id);
                            
            conn.register_object (
                DVB.Constants.DBUS_RECORDINGS_STORE_PATH,
                recstore);
        } catch (Error e) {
            error ("Oops %s", e.message);
            return false;
        }
        
        return true;
    }
    
    private static void on_exit (int signum) {
        message ("Exiting");
        
        server = null;
        
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
    
    public static int main (string[] args) {
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
        
        if (!start_manager ()) return -1;
        
        uint32 max_id = 0;
        
        weak DVB.TimersStore timers_store = DVB.Factory.get_timers_store ();
        weak DVB.ConfigStore config_store = DVB.Factory.get_config_store ();
        
        message ("Restoring device groups");
        Gee.List<DVB.DeviceGroup> device_groups = config_store.get_all_device_groups ();
        foreach (DVB.DeviceGroup device_group in device_groups) {
            
            if (manager.add_device_group (device_group)) {
                DVB.Recorder rec = device_group.recorder;
            
                // Restore timers
                message ("Restoring timers of device group %u", device_group.Id);
                Gee.List<DVB.Timer> timers = timers_store.get_all_timers_of_device_group (device_group);
                foreach (DVB.Timer t in timers) {
                    if (t.Id > max_id) max_id = t.Id;
                    if (rec.add_timer (t) == 0)
                        timers_store.remove_timer_from_device_group (t.Id, device_group);
                }
            }
            
        }
        timers_store = null;
        config_store = null;
        
        if (!start_recordings_store (max_id)) return -1;

        message ("Starting RTSP server");
        server = new Gst.RTSPServer ();
        server.set_media_mapping (new DVB.MediaMapping ());
        server.attach (null);
    
        // Start GLib mainloop
        mainloop.run ();
        
        return 0;
    }

}
