using GLib;
using Gee;

namespace DVB {
    
    [DBus (name = "org.gnome.DVB.Manager")]
    public class Manager : Object {

        // Map object path to Scanner
        private HashMap<string, Scanner> scanners;
        // Maps device group id to Recorder
        private HashMap<uint, Recorder> recorders;
        // Maps device grou to ChannelList
        private HashMap<uint, ChannelList> channellists;
        // Maps device group id to Device
        private HashMap<uint, DeviceGroup> devices;
        
        private uint device_group_counter;
        
        construct {
            this.scanners = new HashMap<string, Scanner> ();
            this.recorders = new HashMap<uint, Recorder> ();
            this.channellists = new HashMap<uint, ChannelList> ();
            this.devices = new HashMap<uint, DeviceGroup> ();
            this.device_group_counter = 0;
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
            
            var conn = get_dbus_connection ();
            
            string dbusiface;
            if (!this.scanners.contains (path)) {
                Device device = new Device (adapter, frontend);
                
                Scanner scanner;
                switch (device.Type) {
                    case AdapterType.DVB_T:
                    scanner = new TerrestrialScanner (device);
                    dbusiface = "org.gnome.DVB.Scanner.Terrestrial";
                    break;
                    
                    case AdapterType.DVB_S:
                    scanner = new SatelliteScanner (device);
                    dbusiface = "org.gnome.DVB.Scanner.Satellite";
                    break;
                    
                    case AdapterType.DVB_C:
                    scanner = new CableScanner (device);
                    dbusiface = "org.gnome.DVB.Scanner.Cable";
                    break;
                }
                
                this.scanners.set (path, scanner);
                
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
         * @returns: adapter and frontend number for each registered device
         */
        public uint[] GetRegisteredDeviceGroups () {
            // FIXME initialize and set array correctly
            uint[] devs = new uint[this.devices.size];
            int i = 0;
            foreach (uint key in this.devices.get_keys ()) {
                devs[i] = key;
                i++;
            }
            return devs;
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @returns: Object path of the device's recorder
         * 
         * Returns the object path to the device's recorder.
         * The device must be registered with RegisterDevice () first.
         */
        public string GetRecorder (uint group_id) {
            string path = Constants.DBUS_RECORDER_PATH.printf (group_id);
        
            if (!this.recorders.contains (group_id)) {
                debug ("Creating new Recorder for group %u",
                    group_id);
                
                DeviceGroup device = this.get_device_group_if_exists (group_id);
                if (device == null) return "";
                
                Recorder recorder = new Recorder (device);
                
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
         * Register a new DVB device
         */
        public bool AddDeviceToNewGroup (uint adapter, uint frontend,
            string channels_conf, string recordings_dir) {
            
            Device device = this.create_device (adapter, frontend, channels_conf,
                recordings_dir);
            
            if (device == null) return false;
            
            device_group_counter++;
            
            this.add_device_group (
                new DeviceGroup (device_group_counter, device));
            
            return true;
        }
        
        public bool AddDeviceToExistingGroup (uint adapter, uint frontend,
            string channels_conf, string recordings_dir, uint group_id) {
            
            if (this.devices.contains (group_id)) {
                Device device = this.create_device (adapter, frontend, channels_conf,
                    recordings_dir);
                    
                if (device == null) return false;
                    
                this.devices.get (group_id).add (device);
                return true;
            } else
                return false;
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @returns: Object path to the ChannelList service for this device
         *
         * The device must be registered with RegisterDevice () first.
         */
        public string GetChannelList (uint group_id) {
            string path = Constants.DBUS_CHANNEL_LIST_PATH.printf (group_id);
            
            if (!this.channellists.contains (group_id)) {
                debug ("Creating new ChannelList D-Bus service for group %u",
                    group_id);
                
                DeviceGroup device = this.get_device_group_if_exists (group_id);
                if (device == null) return "";
                
                ChannelList channels = device.Channels;
                
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
         * @returns: Whether the device has been added successfully
         *
         * Register device, create Recorder and ChannelList D-Bus service
         */
        [DBus (visible = false)]
        public bool add_device_group (DeviceGroup device) {
            this.devices.set (device.Id, device);
            string rec_path = this.GetRecorder (device.Id);
            if (rec_path == "") return false;
            
            string channels_path = this.GetChannelList (device.Id);
            if (channels_path == "") return false;
            
            GConfStore.get_instance ().add_device_group (device);
            
            if (device.Id > device_group_counter)
                device_group_counter = device.Id;
            
            return true;
        }
        
        [DBus (visible = false)]
        public Recorder? get_recorder_for_device_group (DeviceGroup device) {
            uint id = device.Id;
            if (this.recorders.contains (id))
                return this.recorders.get (id);
            else
                return null;
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
        
        private DeviceGroup? get_device_group_if_exists (uint group_id) {;
            if (this.devices.contains (group_id))
                return this.devices.get (group_id);
            else
                return null;
        }
        
    }

}
