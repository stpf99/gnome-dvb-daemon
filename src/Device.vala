using GLib;
using Gst;
namespace DVB {

    public enum AdapterType {
        DVB_T,
        DVB_S,
        DVB_C,
        UNKNOWN
    }

    public class Device : GLib.Object {
    
        private static const int PRIME = 31;

        public uint Adapter { get; construct; }
        public uint Frontend { get; construct; }
        public AdapterType Type { get; construct; }
        public ChannelList Channels { get; set; }
        public File RecordingsDirectory { get; set; }

        public Device (uint adapter, uint frontend) {
            this.Adapter = adapter;
            this.Frontend = frontend;
            this.Type = getAdapterType(adapter);
        }

        public static Device new_full (uint adapter, uint frontend,
            ChannelList channels, File recordings_dir) {
            var dev = new Device (adapter, frontend);            
            dev.Channels = channels;
            dev.RecordingsDirectory = recordings_dir;
            return dev;
        }
        
        public static bool equal (Device* dev1, Device* dev2) {
            if (dev1 == null || dev2 == null) return false;
            
            return (dev1->Adapter == dev2->Adapter
                    && dev2->Frontend == dev2->Frontend);
        }
        
        public static uint hash (Device *device) {
            if (device == null) return 0;
            
            return hash_without_device (device->Adapter, device->Frontend);
        }
        
        public static uint hash_without_device (uint adapter, uint frontend) {
            return 2 * PRIME + PRIME * adapter + frontend;
        }

        private static AdapterType getAdapterType (uint adapter) {
            Element dvbsrc = ElementFactory.make("dvbsrc", "test_dvbsrc");
            dvbsrc.set("adapter", adapter);
            
            Element pipeline = new Pipeline ("");
            ((Bin)pipeline).add (dvbsrc);
            pipeline.set_state (State.READY);
            
            weak Bus bus = pipeline.get_bus();
            
            weak string adapter_type = null;
            
            while (bus.have_pending()) {
                weak Message msg = bus.pop();

                if (msg.type == MessageType.ELEMENT && msg.src == dvbsrc) {
                    weak Structure structure = msg.structure;

                    if (structure.get_name() == "dvb-adapter") {
                        adapter_type = structure.get_string("type");
                        break;
                    }
                } else if (msg.type == MessageType.ERROR) {
                    Error gerror;
                    string debug;
                    msg.parse_error (out gerror, out debug);
                    critical ("%s %s", gerror.message, debug);
                }
            }
               
            pipeline.set_state(State.NULL);

            if (adapter_type == "DVB-T") return AdapterType.DVB_T;
            else if (adapter_type == "DVB-S") return AdapterType.DVB_S;
            else if (adapter_type == "DVB-C") return AdapterType.DVB_C;
            else return AdapterType.UNKNOWN;
        }
    }
    
}
