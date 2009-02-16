using GLib;
using Gst;
namespace DVB {

    public enum AdapterType {
        UNKNOWN,
        DVB_T,
        DVB_S,
        DVB_C
    }

    public class Device : GLib.Object {
    
        private static const int PRIME = 31;

        public uint Adapter { get; construct; }
        public uint Frontend { get; construct; }
        public AdapterType Type { get; construct; }
        public string Name { get; construct; }
        public ChannelList Channels { get; set; }
        public File RecordingsDirectory { get; set; }

        public Device (uint adapter, uint frontend, bool get_type_and_name=true) {
            this.Adapter = adapter;
            this.Frontend = frontend;
            // We can only assign values to properties in constructor
            // as a work-around we forward get_type_and_name
            this.Type = getAdapterType(adapter, get_type_and_name);
            this.Name = getAdapterName(adapter, get_type_and_name);
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
        
        public bool is_busy () {
            Element dvbsrc = ElementFactory.make ("dvbsrc", "text_dvbsrc");
            if (dvbsrc == null) {
                critical ("Could not create dvbsrc element");
                return true;
            }
            dvbsrc.set ("adapter", this.Adapter);
            dvbsrc.set ("frontend", this.Frontend);
            
            Element pipeline = new Pipeline ("");
            ((Bin)pipeline).add (dvbsrc);
            pipeline.set_state (State.READY);
            
            Bus bus = pipeline.get_bus();
            
            bool busy_val = false;
            
            while (bus.have_pending()) {
                Message msg = bus.pop();

                if (msg.type == MessageType.ERROR && msg.src == dvbsrc) {
                    Error gerror;
                    string debug_text;
                    msg.parse_error (out gerror, out debug_text);
                    
                    debug ("Error tuning: %s; %s", gerror.message, debug_text);
                    
                    busy_val = true;
                }
            }
               
            pipeline.set_state(State.NULL);
            
            return busy_val;
        }

        private static AdapterType getAdapterType (uint adapter, bool get_type) {
            if (!get_type) return AdapterType.UNKNOWN;
        
            Element dvbsrc = ElementFactory.make ("dvbsrc", "test_dvbsrc");
            if (dvbsrc == null) {
                critical ("Could not create dvbsrc element");
                return AdapterType.UNKNOWN;
            }
            dvbsrc.set ("adapter", adapter);
            
            Element pipeline = new Pipeline ("");
            ((Bin)pipeline).add (dvbsrc);
            pipeline.set_state (State.READY);
            
            Bus bus = pipeline.get_bus();
            
            string adapter_type = null;
            
            while (bus.have_pending()) {
                Message msg = bus.pop();

                if (msg.type == MessageType.ELEMENT && msg.src == dvbsrc) {
                    weak Structure structure = msg.structure;

                    if (structure.get_name() == "dvb-adapter") {
                        adapter_type = "%s".printf (structure.get_string("type"));
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
        
        private static string? getAdapterName (uint adapter, bool get_name) {
            if (!get_name) return null;
        
            Element dvbsrc = ElementFactory.make ("dvbsrc", "test_dvbsrc");
            if (dvbsrc == null) {
                critical ("Could not create dvbsrc element");
                return null;
            }
            dvbsrc.set ("adapter", adapter);
            
            Element pipeline = new Pipeline ("");
            ((Bin)pipeline).add (dvbsrc);
            pipeline.set_state (State.READY);
            
            Bus bus = pipeline.get_bus();
            
            string adapter_name = null;
            
            while (bus.have_pending()) {
                Message msg = bus.pop();

                if (msg.type == MessageType.ELEMENT && msg.src == dvbsrc) {
                    weak Structure structure = msg.structure;

                    if (structure.get_name() == "dvb-adapter") {
                        adapter_name = "%s".printf (structure.get_string("name"));
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

            return adapter_name;
        }
    }
    
}
