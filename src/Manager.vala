using GLib;
using Gee;

namespace DVB {
    
    //[DBus (name = "org.gnome.DVB.Manager")]
    public class Manager : Object {

        private HashMap<string, Scanner> scanners;
        private HashMap<string, Recorder> recorders;
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
        public string[]? GetScannerForDevice (uint adapter, uint frontend) {
            string path = Constants.DBUS_SCANNER_PATH.printf (adapter, frontend);
            string dbusiface;
            
            if (!this.scanners.contains (path)) {
                debug ("Creating new Scanner D-Bus service for adapter %d, frontend %d",
                      adapter, frontend);
                
                Device device = new Device (adapter, frontend);
                // TODO Tell the user what scanner we created
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
                
                var conn = get_dbus_connection ();
                if (conn == null) return null;
                
                conn.register_object (
                    path,
                    scanner);
            }
            
            return new string[] {path, dbusiface};
        }
        
        /**
         * @returns: A list of Object path's to the recorders of all devices
         */
        public string[] GetRecorders () {
            return new string[] {""};
        }
        
        /**
         * @returns: adapter and frontend number for each registered device
         */
        public uint[][] GetRegisteredDevices () {
            return new uint[][] { new uint[] {0, 0} };
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @returns: Object path of the device's recorder
         * 
         * Returns the object path to the device's recorder.
         * The device must be registered with RegisterDevice () first.
         */
        public string? GetRecorder (uint adapter, uint frontend) {
            
            string path = Constants.DBUS_RECORDER_PATH.printf (adapter, frontend);
            
            if (!this.recorders.contains (path)) {
                debug ("Creating new Recorder for adapter %d, frontend %d");
                
                DVB.Device device = this.devices.get (
                    this.generate_device_id(adapter, frontend));
                // TODO store somewhere
                string recordings_dir = "";
                
                Recorder recorder;
                switch (device.Type) {
                    case AdapterType.DVB_T:
                    recorder = new TerrestrialRecorder (device, recordings_dir);
                    break;
                    
                    case AdapterType.DVB_S:
                    recorder = new SatelliteRecorder (device, recordings_dir);
                    break;
                    
                    case AdapterType.DVB_C:
                    recorder = new CableRecorder (device, recordings_dir);
                    break;
                }
                
                var conn = get_dbus_connection ();
                if (conn == null) return null;
                
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
            
            Device device = new Device (adapter, frontend);
            
            File channelsfile = File.new_for_path (channels_conf);
            
            var reader = new DVB.ChannelListReader (channelsfile, device.Type);
            reader.read ();
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
        
        private static int generate_device_id (uint adapter, uint frontend) {
            // TODO generate unique id
            return (int)(adapter + frontend);
        }
    }

}
