using GLib;
using Gee;

namespace DVB {
    
    //[DBus (name = "org.gnome.DVB.Manager")]
    public class Manager : Object {
    
        private static const int PRIME = 31;

        // Map object path to Scanner
        private HashMap<string, Scanner> scanners;
        // Maps object path to Recorder
        private HashMap<string, Recorder> recorders;
        // Maps device id to Device
        private HashMap<int, Device> devices;
        
        construct {
            this.scanners = new HashMap<string, Scanner> (str_hash, str_equal, direct_equal);
            this.recorders = new HashMap<string, Recorder> (str_hash, str_equal, direct_equal);
            this.devices = new HashMap<int, Device> ();
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
            try {
                dynamic DBus.Object bus = conn.get_object (
                        "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus");
                
                // try to register service in session bus
                uint request_name_result = bus.RequestName (DVB.Constants.DBUS_SERVICE, (uint) 0);
            } catch (Error e) {
                critical (e.message);
            }
            
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
         * @returns: A list of Object path's to the recorders of all devices
         */
        public string[] GetRecorders () {
            string[] recs = new string[this.recorders.size];
            int i = 0;
            foreach (string key in this.recorders.get_keys ()) {
                recs[i] = key;
                i++;
            }
            return recs;
        }
        
        /**
         * @returns: adapter and frontend number for each registered device
         */
        public uint[][] GetRegisteredDevices () {
            uint[][] devs = new uint[this.devices.size][2];
            int i = 0;
            foreach (int key in this.devices.get_keys ()) {
                devs[i][0] = this.devices.get (key).Adapter;
                devs[i][1] = this.devices.get (key).Frontend;
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
        public string GetRecorder (uint adapter, uint frontend) {
            
            string path = Constants.DBUS_RECORDER_PATH.printf (adapter, frontend);
            
            if (!this.recorders.contains (path)) {
                debug ("Creating new Recorder for adapter %u, frontend %u",
                    adapter, frontend);
                
                Device device = this.get_device_if_exists (adapter, frontend);
                if (device == null) return "";
                
                Recorder recorder = new Recorder (device);
                
                var conn = get_dbus_connection ();
                if (conn == null) return "";
                
                conn.register_object (
                    path,
                    recorder);
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
        public bool RegisterDevice (uint adapter, uint frontend,
            string channels_conf, string recordings_dir) {
            // TODO Check if adapter and frontend exists
            
            File channelsfile = File.new_for_path (channels_conf);
            File recdir = File.new_for_path (recordings_dir);
            
            Device device = new Device (adapter, frontend);
            device.RecordingsDirectory = recdir;
            
            var reader = new DVB.ChannelListReader (channelsfile, device.Type);
            try {
                reader.read ();
            } catch (Error e) {
                critical (e.message);
                return false;
            }
            
            device.Channels = reader.Channels;
            
            this.devices.set (this.generate_device_id(adapter, frontend),
                              device);
            
            return true;
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @returns: Object path to the ChannelList service for this device
         *
         * The device must be registered with RegisterDevice () first.
         */
        public string GetChannelList (uint adapter, uint frontend) {
            return "";
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
        
        private Device? get_device_if_exists (uint adapter, uint frontend) {
            int id = generate_device_id (adapter, frontend);
            if (this.devices.contains (id))
                return this.devices.get (id);
            else {
                message ("No device with adapter %u and frontend %u",
                    adapter, frontend);
                return null;
            }
        }
        
        private static int generate_device_id (uint adapter, uint frontend) {
            int result = 2 * PRIME + PRIME * (int)adapter + (int)frontend;
            return result;
        }
    }

}
