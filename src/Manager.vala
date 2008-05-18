using GLib;
using Gee;

namespace DVB {

    [DBus (name = "org.gnome.DVB.Manager")]
    public class Manager : Object {

        private HashMap<string, Scanner> scanners;
        
        construct {
            this.scanners = new HashMap<string, Scanner> (str_hash, str_equal, direct_equal);
        }
        
        public string GetScannerForDevice (uint adapter, uint frontend) {
            
            string path = Constants.DBUS_SCANNER_PATH.printf (adapter, frontend);
            
            if (!this.scanners.contains (path)) {
                debug("Creating new Scanner D-Bus service for adapter %d, frontend %d",
                      adapter, frontend);
                
                var conn = DBus.Bus.get (DBus.BusType.SESSION);
                
                Device device = new Device (adapter, frontend);
                Scanner scanner = new Scanner (device);
                this.scanners.set (path, scanner);
                
                conn.register_object (
                    path,
                    scanner);
            }
            
            return path;
        }

    }

}
