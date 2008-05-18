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

        public uint Adapter { get; construct; }
        public uint Frontend { get; construct; }
        public AdapterType Type { get; construct; }
        
        public Device (uint adapter, uint frontend) {
            this.Adapter = adapter;
            this.Frontend = frontend;
            this.Type = getAdapterType(adapter);
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
