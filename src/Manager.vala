using GLib;
using Gee;

namespace DVB {
    
    [DBus (name = "org.gnome.DVB.Manager")]
    public class Manager : Object {
        
        /**
         * @type: 0: added, 1: deleted, 2: updated
         *
         * Emitted when a group has been added or deleted
         */
        public signal void changed (uint group_id, uint change_type);
        
        /**
         * Emitted when a device has been added or removed from a group
         */
        public signal void group_changed (uint group_id, uint adapter,
            uint frontend, uint change_type);

        // Map object path to Scanner
        private HashMap<string, Scanner> scanners;
        // Maps device group id to Recorder
        private HashMap<uint, Recorder> recorders;
        // Maps device group to ChannelList
        private HashMap<uint, ChannelList> channellists;
        // Maps device group id to Device
        private HashMap<uint, DeviceGroup> devices;
        // Maps device group id to EPGScanner
        private HashMap<uint, EPGScanner> epgscanners;
        // Containss object paths to Schedule 
        private HashSet<string> schedules;
        
        private uint device_group_counter;
        
        private static Manager instance;
        
        construct {
            this.scanners = new HashMap<string, Scanner> (GLib.str_hash,
                GLib.str_equal, GLib.direct_equal);
            this.recorders = new HashMap<uint, Recorder> ();
            this.channellists = new HashMap<uint, ChannelList> ();
            this.devices = new HashMap<uint, DeviceGroup> ();
            this.epgscanners = new HashMap<uint, EPGScanner> ();
            this.schedules = new HashSet<string> (GLib.str_hash,
                GLib.str_equal);
            this.device_group_counter = 0;
        }
        
        [DBus (visible = false)]
        public static weak Manager get_instance () {
            // TODO make thread-safe
            if (instance == null) {
                instance = new Manager ();
            }
            return instance;
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
                    this.get_epg_scanner (this.get_device_group_of_device (
                        reg_dev));
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
                debug ("Creating new Recorder for group %u",
                    group_id);
                
                DeviceGroup devgroup = this.get_device_group_if_exists (group_id);
                if (devgroup == null) return "";
                
                Recorder recorder = new Recorder (devgroup);
                
                var conn = get_dbus_connection ();
                if (conn == null) return "";
                
                conn.register_object (
                    path,
                    recorder);
                    
                this.recorders.set (group_id, recorder);
            }
            
            return path;
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @channels_conf: Path to channels.conf for this device
         * @recordings_dir: Path where the recordings should be stored
         * @returns: TRUE when the device has been registered successfully
         *
         * Creates a new DeviceGroup and new DVB device whereas the
         * DVB device is the reference device of this group (i.e.
         * all other devices of this group will inherit the settings
         * of the reference device).
         */
        public bool AddDeviceToNewGroup (uint adapter, uint frontend,
                string channels_conf, string recordings_dir) {
            
            Device device = this.create_device (adapter, frontend, channels_conf,
                recordings_dir);
            
            if (device == null) return false;
            
            // Check if device is already assigned to other group
            if (this.device_is_in_any_group (device)) return false;
            
            device_group_counter++;
            
            this.add_device_group (
                new DeviceGroup (device_group_counter, device));
            
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
                    GConfStore.get_instance ().add_device_to_group (device,
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
                            this.get_epg_scanner (devgroup);
                        if (epgscanner != null) epgscanner.stop ();
                    
                        GConfStore.get_instance ().remove_device_from_group (
                            dev, devgroup);
                        this.group_changed (group_id, adapter, frontend,
                            ChangeType.DELETED);
                            
                        // Group has no devices anymore, delete it
                        if (devgroup.size == 0) {
                            if (this.devices.remove (group_id)) {
                                // Remove EPG scanner, too
                                if (epgscanner != null)
                                    this.epgscanners.remove (devgroup.Id);
                                GConfStore.get_instance ().remove_device_group (
                                    devgroup);
                                this.changed (group_id, ChangeType.DELETED);
                            }
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
                    
                this.channellists.set (group_id, channels);
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
                        
                        Schedule schedule = devgroup.Channels.get (channel_sid).Schedule;
                        
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
        [DBus (visible = false)]
        public bool add_device_group (DeviceGroup devgroup) {
            debug ("Adding device group %u with %d devices", devgroup.Id,
                devgroup.size);
        
            this.devices.set (devgroup.Id, devgroup);
            string rec_path = this.GetRecorder (devgroup.Id);
            if (rec_path == "") return false;
            
            string channels_path = this.GetChannelList (devgroup.Id);
            if (channels_path == "") return false;
            
            GConfStore.get_instance ().add_device_group (devgroup);
            
            if (devgroup.Id > device_group_counter)
                device_group_counter = devgroup.Id;
            
            return true;
        }
        
        [DBus (visible = false)]
        public Recorder? get_recorder_for_device_group (DeviceGroup devgroup) {
            uint id = devgroup.Id;
            if (this.recorders.contains (id))
                return this.recorders.get (id);
            else
                return null;
        }
        
        [DBus (visible = false)]
        public EPGScanner? get_epg_scanner (DeviceGroup devgroup) {
            return this.epgscanners.get (devgroup.Id);
        }
        
        [DBus (visible = false)]
        public void create_and_start_epg_scanner (DeviceGroup devgroup) { 
            debug ("Creating new EPG scanner for device group %u",
                devgroup.Id);
        
            EPGScanner? epgscanner = new EPGScanner (devgroup);
            epgscanner.start ();
            this.epgscanners.set (devgroup.Id, epgscanner);
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
                critical (e.message);
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
                error(e.message);
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
            
            debug ("Destroying scanner for adapter %u, frontend %u", adapter,
                frontend);
            
            string path = Constants.DBUS_SCANNER_PATH.printf (adapter, frontend);
            this.scanners.remove (path);
            
            // Start epgscanner for device again if there was one
            DeviceGroup? devgroup = this.get_device_group_of_device (scanner.Device);
            if (devgroup != null) {
                EPGScanner? epgscanner = this.get_epg_scanner (devgroup);
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
        
    }

}
