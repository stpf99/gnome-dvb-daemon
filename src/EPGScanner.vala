using GLib;
using Gst;

namespace DVB {

    public class EPGScanner : GLib.Object {
    
        public DVB.Device Device {get; set;}
        
        private Element? pipeline;
        
        public EPGScanner (DVB.Device device) {
            this.Device = device;
        }
    
        public void start () {
            // pids: 0=pat, 16=nit, 17=sdt, 18=eit
            try {
                this.pipeline = Gst.parse_launch(
                    "dvbsrc name=dvbsrc adapter=%u frontend=%u ".printf(
                    this.Device.Adapter, this.Device.Frontend)
                    + "pids=0:16:17:18 stats-reporting-interval=0 "
                    + "! mpegtsparse ! fakesink silent=true");
            } catch (Error e) {
                error (e.message);
                return;
            }
            
            weak Gst.Bus bus = this.pipeline.get_bus();
            bus.add_signal_watch();
            bus.message += this.bus_watch_func;
            
            this.pipeline.set_state(Gst.State.READY);
        }
        
        public void stop () {
            if (this.pipeline != null)
                this.pipeline.set_state (Gst.State.NULL);
            this.pipeline = null;
        }
        
        private void bus_watch_func (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
                case Gst.MessageType.ELEMENT:
                    if (message.structure.get_name() == "dvb-read-failure") {
                        critical ("Could not read from DVB device");
                        this.stop ();
                    } else if (message.structure.get_name() == "eit") {
                        this.on_eit_structure (message.structure);
                    }
                break;
                
                case Gst.MessageType.ERROR:
                    Error gerror;
                    string debug;
                    message.parse_error (out gerror, out debug);
                    critical ("%s %s", gerror.message, debug);
                    this.stop ();
                break;
                
                default:
                break;
            }
        }
        
        protected void on_eit_structure (Gst.Structure structure) {
        
        }
    }
}
