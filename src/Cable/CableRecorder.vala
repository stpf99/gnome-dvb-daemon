using GLib;
using Gst;

namespace DVB {

    public class CableRecorder : Recorder {
    
        public CableRecorder (Device dev) {
            base.Device = dev;
        }
    
        protected override void get_dvbbasebin (Channel channel) {
            if (!(channel is CableChannel)) {
                warning("Cannot setup pipeline for non-cable channel");
                this.dvbbasebin = null;
            }
            CableChannel cchannel = (CableChannel)channel;
            
            this.dvbbasebin = ElementFactory.make ("dvbbasebin", "dvbbasebin");
            this.dvbbasebin.set ("frequency", cchannel.Frequency);
            this.dvbbasebin.set ("inversion", cchannel.Inversion);
            this.dvbbasebin.set ("symbol-rate", cchannel.SymbolRate);
            this.dvbbasebin.set ("code-rate-hp", cchannel.CodeRate);
            this.dvbbasebin.set ("modulation", cchannel.Modulation);
        }
    }

}
