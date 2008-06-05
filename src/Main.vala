using GLib;

public class Main {

    private static DVB.Manager manager;

    private static void start_manager () {
    
        try {
            var conn = DBus.Bus.get (DBus.BusType.SESSION);
            
            dynamic DBus.Object bus = conn.get_object (
                    "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus");
            
            // try to register service in session bus
            uint request_name_result = bus.RequestName (DVB.Constants.DBUS_SERVICE, (uint) 0);

            if (request_name_result == DBus.RequestNameReply.PRIMARY_OWNER) {
                debug("Creating new Manager D-Bus service");
            
                manager = new DVB.Manager ();
                                
                conn.register_object (
                    DVB.Constants.DBUS_MANAGER_PATH,
                    manager);
            } else {
                debug("Manager D-Bus service is already running");
            }

        } catch (Error e) {
            error("Oops %s", e.message);
        }
    }

    public static void main (string[] args) {
        MainLoop loop;
    
        // Creating a GLib main loop with a default context
        loop = new MainLoop (null, false);

        // Initializing GStreamer
        Gst.init (ref args);
        
        File channelsfile = File.new_for_path ("/home/sebp/.gstreamer-0.10/dvb-channels.conf");
        var reader = new DVB.ChannelListReader (channelsfile, DVB.AdapterType.DVB_T);
        reader.read ();
        
        DVB.Device device = new DVB.Device(0, 0, reader.Channels);
        var rec = new DVB.TerrestrialRecorder (device, "/home/sebp/TV");
        uint id = rec.AddTimer (16403, 2008, 5, 25, 12, 49, 2);
        stdout.printf ("Id is %d\n", id);
        
        //start_manager();
        /*
        Gst.Structure pro7 = new Gst.Structure ("pro7",
                "hierarchy", typeof(uint), DVB.DvbSrcHierarchy.HIERARCHY_AUTO,
                "bandwidth", typeof(uint), DVB.DvbSrcBandwidth.BANDWIDTH_8_MHZ,
                "frequency", typeof(uint), 690000000,
                "transmission-mode", typeof(uint), DVB.DvbSrcTransmissionMode.TRANSMISSION_MODE_8K,
                "code-rate-hp", typeof(uint), DVB.DvbSrcCodeRate.FEC_NONE,
                "code-rate-lp", typeof(uint), DVB.DvbSrcCodeRate.FEC_AUTO,
                "constellation", typeof(uint), DVB.DvbSrcModulation.QAM_64,
                "guard-interval", typeof(uint), DVB.DvbSrcGuard.GUARD_INTERVAL_AUTO);
        
        DVB.Scanner scanner = new DVB.Scanner(device);
        scanner.add_frequency(#pro7);
        scanner.run();
        */
        // Start GLib mainloop
        loop.run ();
    }

}
