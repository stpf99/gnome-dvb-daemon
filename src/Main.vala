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
    
    private static void recording_finished (DVB.Recorder recorder, uint32 id) {
        stdout.printf ("Recording %d finished\n", id);
        
        weak DVB.RecordingsStore rec = DVB.RecordingsStore.get_instance();
        
        foreach (uint32 rid in rec.GetRecordings()) {
            stdout.printf ("ID: %d\n", rid);
            stdout.printf ("Location: %s\n", rec.GetLocation (rid));
            stdout.printf ("Length: %d\n", rec.GetLength (rid));
            uint[] start = rec.GetStartTime (rid);
            stdout.printf ("Start: %d-%d-%d %d:%d\n", start[0], start[1],
                start[2], start[3], start[4]);
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
        try {
            reader.read ();
        } catch (Error e) {
            error (e.message);
        }

        File recdir = File.new_for_path ("/home/sebp/TV");

        DVB.Device device = DVB.Device.new_full (0, 0,
            reader.Channels, recdir);
        var rec = new DVB.TerrestrialRecorder (device);
        rec.recording_finished += recording_finished;
        
        //DVB.RecordingsStore.get_instance ().Delete ((uint32)1);
        
        rec.AddTimer (16394, 2008, 6, 12, 11, 30, 2);
        rec.AddTimer (32, 2008, 6, 9, 21, 39, 3);
        rec.AddTimer (32, 2008, 6, 5, 10, 25, 3);
        rec.AddTimer (99999, 2008, 6, 20, 10, 55, 9);
        rec.AddTimer (16418, 2006, 6, 6, 6, 6, 99);

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
