using GLib;
using Gee;

namespace DVB {
    
    public class Manager : Object, IDBusManager {
        
        // Map object path to Scanner
        private HashMap<string, Scanner> scanners;
        
        // Maps device group id to Device
        private HashMap<uint, DeviceGroup> devices;
        
        // Containss object paths to Schedule 
        private HashSet<string> schedules;
        
        // Contains group ids
        private HashSet<uint> recorders;
        private HashSet<uint> channellists;
        private HashSet<uint> epgscanners;
        
        private uint device_group_counter;
        
        private static Manager instance;
        private static StaticRecMutex instance_mutex = StaticRecMutex ();
        
        construct {
            this.scanners = new HashMap<string, Scanner> (GLib.str_hash,
                GLib.str_equal, GLib.direct_equal);
            this.devices = new HashMap<uint, DeviceGroup> ();
            this.schedules = new HashSet<string> (GLib.str_hash,
                GLib.str_equal);
            this.recorders = new HashSet<uint> ();
            this.channellists = new HashSet<uint> ();
            this.epgscanners = new HashSet<uint> ();
            this.device_group_counter = 0;
        }
        
        public static weak Manager get_instance () {
            instance_mutex.lock ();
            if (instance == null) {
                instance = new Manager ();
            }
            instance_mutex.unlock ();
            return instance;
        }
        
        public static void shutdown () {
            instance_mutex.lock ();
            Manager m = instance;
            
            if (instance != null) {
                foreach (Scanner scanner in m.scanners.get_values ()) {
                    debug ("Stopping scanner");
                    scanner.Destroy ();
                }
                m.scanners.clear ();
                
                m.schedules.clear ();
                m.recorders.clear ();
                m.channellists.clear ();
                m.epgscanners.clear ();
                
                foreach (DeviceGroup devgrp in m.devices.get_values ()) {
                    devgrp.destroy ();
                }
                m.devices.clear ();
                
                instance = null;
            }
            instance_mutex.unlock ();
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @returns: Object path and interface to the scanner service
         *
         * Get the object path of the channel scanner for this device.
         */
        public string[] GetScannerForDevice (uint adapter, uint frontend) {
            string path = Constants.DBUS_SCANNER_PATH.printf (adapter, frontend);
            
            Device device;
            Device? reg_dev = this.get_registered_device (adapter, frontend);
            
            if (reg_dev == null) {
                // Create new device
                device = new Device (adapter, frontend);
            } else {
                // Stop epgscanner for device if there's any
                EPGScanner? epgscanner =
                    this.get_device_group_of_device (
                        reg_dev).epgscanner;
                if (epgscanner != null) epgscanner.stop ();
                
                // Assign existing device
                device = reg_dev;
            }
                
            string dbusiface = null;
            switch (device.Type) {
                case AdapterType.DVB_T:
                dbusiface = "org.gnome.DVB.Scanner.Terrestrial";
                break;
                
                case AdapterType.DVB_S:
                dbusiface = "org.gnome.DVB.Scanner.Satellite";
                break;
                
                case AdapterType.DVB_C:
                dbusiface = "org.gnome.DVB.Scanner.Cable";
                break;
            }
            
            if (dbusiface == null) {
                critical ("Unknown adapter type");
                return new string[] {"", ""};
            }
                
            if (!this.scanners.contains (path)) {
                Scanner scanner = null;
                switch (device.Type) {
                    case AdapterType.DVB_T:
                    scanner = new TerrestrialScanner (device);
                    break;
                    
                    case AdapterType.DVB_S:
                    scanner = new SatelliteScanner (device);
                    break;
                    
                    case AdapterType.DVB_C:
                    scanner = new CableScanner (device);
                    break;
                }
                
                if (scanner == null) {
                    critical ("Unknown adapter type");
                    return new string[] {"", ""};
                }
                
                scanner.destroyed += this.on_scanner_destroyed;
                
                this.scanners.set (path, scanner);
                
                var conn = get_dbus_connection ();
                if (conn == null) return new string[] {};
                
                conn.register_object (
                    path,
                    scanner);
                
                debug ("Created new Scanner D-Bus service for adapter %u, frontend %u (%s)",
                      adapter, frontend, dbusiface);
            }
            
            return new string[] {path, dbusiface};
        }
        
        /**
         * @returns: Device groups' ID
         */
        public uint[] GetRegisteredDeviceGroups () {
            uint[] devs = new uint[this.devices.size];
            int i = 0;
            foreach (uint key in this.devices.get_keys ()) {
                devs[i] = key;
                i++;
            }
            return devs;
        }
        
        /**
         * @group_id: ID of device group
         * @returns: Name of adapter type the group holds
         * or an empty string when group with given id doesn't exist.
         */
        public string GetTypeOfDeviceGroup (uint group_id) {
            if (this.devices.contains (group_id)) {
                DeviceGroup devgroup = this.devices.get (group_id);
                string type_str;
                switch (devgroup.Type) {
                    case AdapterType.DVB_T: type_str = "DVB-T"; break;
                    case AdapterType.DVB_S: type_str = "DVB-S"; break;
                    case AdapterType.DVB_C: type_str = "DVB-C"; break;
                    default: type_str = ""; break;
                }
                return type_str;
            }
            
            return "";
        }
        
        /**
         * @group_id: ID of device group
         * @returns: Object path of the device's recorder
         * 
         * Returns the object path to the device's recorder.
         * The device group must be registered with AddDeviceToNewGroup () first.
         */
        public string GetRecorder (uint group_id) {
            string path = Constants.DBUS_RECORDER_PATH.printf (group_id);
        
            if (!this.recorders.contains (group_id)) {
                debug ("Creating new Recorder D-Bus service for group %u",
                    group_id);
                
                DeviceGroup devgroup = this.get_device_group_if_exists (group_id);
                if (devgroup == null) return "";
                
                Recorder recorder = devgroup.recorder;
                
                var conn = get_dbus_connection ();
                if (conn == null) return "";
                
                conn.register_object (
                    path,
                    recorder);
                    
                this.recorders.add (group_id);
            }
            
            return path;
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @channels_conf: Path to channels.conf for this device
         * @recordings_dir: Path where the recordings should be stored
         * @name: Name of group
         * @returns: TRUE when the device has been registered successfully
         *
         * Creates a new DeviceGroup and new DVB device whereas the
         * DVB device is the reference device of this group (i.e.
         * all other devices of this group will inherit the settings
         * of the reference device).
         */
        public bool AddDeviceToNewGroup (uint adapter, uint frontend,
                string channels_conf, string recordings_dir, string name) {
            
            Device device = this.create_device (adapter, frontend, channels_conf,
                recordings_dir);
            
            if (device == null) return false;
            
            // Check if device is already assigned to other group
            if (this.device_is_in_any_group (device)) return false;
            
            device_group_counter++;
            
            DeviceGroup devgroup = new DeviceGroup (device_group_counter, device);
            devgroup.Name = name;
            
            this.add_device_group (devgroup);
            
            this.changed (device_group_counter, ChangeType.ADDED);
            
            return true;
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @group_id: ID of device group
         * @returns: TRUE when the device has been registered successfully
         *
         * Creates a new device and adds it to the specified DeviceGroup.
         * The new device will inherit all settings from the group's
         * reference device.
         */
        public bool AddDeviceToExistingGroup (uint adapter, uint frontend,
                uint group_id) {
            
            if (this.devices.contains (group_id)) {
                // When the device is already registered we
                // might see some errors if the device is
                // currently in use
                Device device = new Device (adapter, frontend);
                    
                if (device == null) return false;
                
                if (this.device_is_in_any_group (device)) {
                    debug ("Device with adapter %u, frontend %u is" + 
                        "already part of a group", adapter, frontend);
                    return false;
                }
                    
                debug ("Adding device with adapter %u, frontend %u to group %u",
                    adapter, frontend, group_id);
                    
                DeviceGroup devgroup = this.devices.get (group_id);
                if (devgroup.add (device)) {
                    Factory.get_config_store ().add_device_to_group (device,
                        devgroup);
                    
                    this.group_changed (group_id, adapter, frontend,
                        ChangeType.ADDED);
                
                    return true;
                }
            }
            
            return false;
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @group_id: ID of device group
         * @returns: TRUE when device has been removed successfully
         *
         * Removes the device from the specified group. If the group contains
         * no devices after the removal it's removed as well.
         */
        public bool RemoveDeviceFromGroup (uint adapter, uint frontend,
                uint group_id) {
            if (this.devices.contains (group_id)) {
                DeviceGroup devgroup = this.devices.get (group_id);
                Device dev = new Device (adapter, frontend, false);
                
                if (devgroup.contains (dev)) {
                    if (devgroup.remove (dev)) {
                        // Stop epgscanner, because it might use the
                        // device we want to unregister
                        EPGScanner? epgscanner =
                            devgroup.epgscanner;
                        if (epgscanner != null) epgscanner.stop ();
                    
                        Factory.get_config_store ().remove_device_from_group (
                            dev, devgroup);
                        this.group_changed (group_id, adapter, frontend,
                            ChangeType.DELETED);
                            
                        // Group has no devices anymore, delete it
                        if (devgroup.size == 0) {
                            this.remove_group (devgroup);
                        } else {
                            // We still have a device, start EPG scanner again
                            if (epgscanner != null) epgscanner.start ();
                        }
                            
                        return true;
                    }
                }
            }
            
            return false;
        }
        
        /**
         * @group_id: ID of device group
         * @returns: Name of specified device group or
         * empty string if group with given ID doesn't exist
         */
        public string GetDeviceGroupName (uint group_id) {
            string val = "";
            if (this.devices.contains (group_id)) {
                DeviceGroup devgroup = this.devices.get (group_id);
                val = devgroup.Name;
            }
            return val;
        }
        
        /**
         * @group_id: ID of device group
         * @returns: Object path to the ChannelList service for this device
         *
         * The device group must be registered with AddDeviceToNewGroup () first.
         */
        public string GetChannelList (uint group_id) {
            string path = Constants.DBUS_CHANNEL_LIST_PATH.printf (group_id);
            
            if (!this.channellists.contains (group_id)) {
                debug ("Creating new ChannelList D-Bus service for group %u",
                    group_id);
                
                DeviceGroup devgroup = this.get_device_group_if_exists (group_id);
                if (devgroup == null) return "";
                
                ChannelList channels = devgroup.Channels;
                
                var conn = get_dbus_connection ();
                if (conn == null) return "";
                
                conn.register_object (
                    path,
                    channels);
                    
                this.channellists.add (group_id);
            }
            
            return path;
        }
        
        /**
         * @group_id: ID of device group
         * @returns: List of paths to the devices that are part of
         * the specified group (e.g. /dev/dvb/adapter0/frontend0)
         */
        public string[] GetDeviceGroupMembers (uint group_id) {
            string[] groupdevs;
        
            if (this.devices.contains (group_id)) {
                DeviceGroup devgroup = this.devices.get(group_id);
                groupdevs = new string[devgroup.size];
                
                int i=0;
                foreach (Device dev in devgroup) {
                    groupdevs[i] = Constants.DVB_DEVICE_PATH.printf (
                        dev.Adapter, dev.Frontend);
                    i++;
                }
            } else {
                groupdevs = new string[0];
            }
            
            return groupdevs;
        }
        
        /**
         * @adapter: Adapter of device
         * @frontend: Frontend of device
         * @returns: The name of the device or "Unknown"
         *
         * The device must be part of group, otherwise "Unknown"
         * is returned.
         */
        public string GetNameOfRegisteredDevice (uint adapter, uint frontend) {
            Device? dev = this.get_registered_device (adapter, frontend);
            
            if (dev == null)
                return "Unknown";
            else
                return dev.Name;
        }
        
        public string GetSchedule (uint group_id, uint channel_sid) {
            if (this.devices.contains (group_id)) {
                DeviceGroup devgroup = this.devices.get(group_id);
                
                if (devgroup.Channels.contains (channel_sid)) {
                    string path = Constants.DBUS_SCHEDULE_PATH.printf (group_id, channel_sid);
                    
                    if (!this.schedules.contains (path)) {
                        var conn = get_dbus_connection ();
                        if (conn == null) return "";
                        
                        Schedule schedule = devgroup.Channels.get_channel (
                            channel_sid).Schedule;
                        
                        conn.register_object (
                            path,
                            schedule);
                            
                        this.schedules.add (path);
                    }
                    
                    return path;
                }
            }
        
            return "";
        }
        
        /**
         * @returns: Whether the device has been added successfully
         *
         * Register device, create Recorder and ChannelList D-Bus service
         */
        public bool add_device_group (DeviceGroup devgroup) {
            debug ("Adding device group %u with %d devices", devgroup.Id,
                devgroup.size);
            
            bool success;
            if (devgroup.Type != AdapterType.UNKNOWN) {
                this.devices.set (devgroup.Id, devgroup);
                string rec_path = this.GetRecorder (devgroup.Id);
                
                string channels_path = this.GetChannelList (devgroup.Id);
                
                Factory.get_config_store ().add_device_group (devgroup);
                
                success = (rec_path != "" && channels_path != "");
            } else {
                warning ("Not adding device group %u of unknown type",
                    devgroup.Id);
                success = false;
            }
            
            if (devgroup.Id > device_group_counter)
                device_group_counter = devgroup.Id;
                
            
            if (!Main.get_disable_epg_scanner ()) {
                devgroup.epgscanner.start ();
            }
            
            return success;
        }
        
        private static Device? create_device (uint adapter, uint frontend,
                string channels_conf, string recordings_dir) {
            // TODO Check if adapter and frontend exists
            File channelsfile = File.new_for_path (channels_conf);
            File recdir = File.new_for_path (recordings_dir);
            
            Device device = new Device (adapter, frontend);
            device.RecordingsDirectory = recdir;
            
            ChannelList channels;
            try {
                channels = DVB.ChannelList.restore_from_file (channelsfile, device.Type);
            } catch (Error e) {
                critical ("Could not create channels list from %s: %s",
                    channels_conf, e.message);
                return null;
            }
            
            device.Channels = channels;
            
            return device;
        }
        
        private static DBus.Connection? get_dbus_connection () {
            DBus.Connection conn;
            try {
                conn = DBus.Bus.get (DBus.BusType.SESSION);
            } catch (Error e) {
                error("Could not get D-Bus session bus: %s", e.message);
                return null;
            }
            return conn;
        }
        
        protected DeviceGroup? get_device_group_if_exists (uint group_id) {;
            if (this.devices.contains (group_id))
                return this.devices.get (group_id);
            else
                return null;
        }
        
        private bool device_is_in_any_group (Device device) {
            foreach (uint group_id in this.devices.get_keys ()) {
                DeviceGroup devgroup = this.devices.get (group_id);
                if (devgroup.contains (device)) return true;
            }
            return false;
        }
        
        private void on_scanner_destroyed (Scanner scanner) {
            uint adapter = scanner.Device.Adapter;
            uint frontend = scanner.Device.Frontend;
            
            string path = Constants.DBUS_SCANNER_PATH.printf (adapter, frontend);
            this.scanners.remove (path);
            
            debug ("Destroying scanner for adapter %u, frontend %u (%s)", adapter,
                frontend, path);
            
            // Start epgscanner for device again if there was one
            DeviceGroup? devgroup = this.get_device_group_of_device (scanner.Device);
            if (devgroup != null) {
                EPGScanner? epgscanner = devgroup.epgscanner;
                if (epgscanner != null) epgscanner.start ();
            }
        }
        
        private Device? get_registered_device (uint adapter, uint frontend) {
            Device fake_device = new Device (adapter, frontend, false);
            foreach (uint group_id in this.devices.get_keys ()) {
                DeviceGroup devgroup = this.devices.get (group_id);
                if (devgroup.contains (fake_device)) {
                    foreach (Device device in devgroup) {
                        if (Device.equal (fake_device, device))
                            return device;
                    }
                }
            }
            
            return null;
        }
        
        private DeviceGroup? get_device_group_of_device (Device device) {
            foreach (uint group_id in this.devices.get_keys ()) {
                DeviceGroup devgroup = this.devices.get (group_id);
                if (devgroup.contains (device)) {
                    foreach (Device grp_device in devgroup) {
                        if (Device.equal (grp_device, device))
                            return devgroup;
                    }
                }
            }
            
            return null;
        }
        
        private void remove_group (DeviceGroup devgroup) {
            uint group_id = devgroup.Id;
            if (this.devices.remove (group_id)) {
                this.recorders.remove (group_id);
                this.channellists.remove (group_id);
                this.epgscanners.remove (group_id);
                
                EPGScanner? epgscanner = devgroup.epgscanner;
                // Remove EPG scanner, too
                if (epgscanner != null)
                    this.epgscanners.remove (group_id);
                    
                devgroup.destroy ();
                
                Factory.get_config_store ().remove_device_group (
                    devgroup);
                
                this.changed (group_id, ChangeType.DELETED);
            }
        }
        
    }

}
