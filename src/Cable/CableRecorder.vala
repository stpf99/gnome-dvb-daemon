using GLib;
using Gst;

namespace DVB {

    public class CableRecorder : Recorder {
    
        public CableRecorder (Device dev) {
            base.Device = dev;
        }
    
        protected override weak Element? get_dvbbasebin (Channel channel) {
            if (!(channel is CableChannel)) {
                warning("Cannot setup pipeline for non-cable channel");
                return null;
            }
            CableChannel cchannel = (CableChannel)channel;
            
            Element dvbbasebin = ElementFactory.make ("dvbbasebin", "dvbbasebin");
            dvbbasebin.set ("frequency", cchannel.Frequency);
            dvbbasebin.set ("inversion", cchannel.Inversion);
            dvbbasebin.set ("symbol-rate", cchannel.SymbolRate);
            dvbbasebin.set ("code-rate-hp", cchannel.CodeRate);
            dvbbasebin.set ("modulation", cchannel.Modulation);
            
            return dvbbasebin;
        }
    }

}
