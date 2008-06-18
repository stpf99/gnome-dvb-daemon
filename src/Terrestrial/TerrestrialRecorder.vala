using GLib;
using Gst;

namespace DVB {

    public class TerrestrialRecorder : Recorder {
    
        public TerrestrialRecorder (Device dev) {
            base.Device = dev;
        }
    
        protected override weak Element? get_dvbbasebin (Channel channel) {
            if (!(channel is TerrestrialChannel)) {
                warning("Cannot setup pipeline for non-terrestrial channel");
                return null;
            }
            TerrestrialChannel tchannel = (TerrestrialChannel)channel;
            
            Element dvbbasebin = ElementFactory.make ("dvbbasebin", "dvbbasebin");
            dvbbasebin.set ("modulation", tchannel.Constellation);
            dvbbasebin.set ("trans-mode", tchannel.TransmissionMode);
            dvbbasebin.set ("code-rate-hp", tchannel.CodeRateHP);
            dvbbasebin.set ("code-rate-lp", tchannel.CodeRateLP);
            dvbbasebin.set ("guard", tchannel.GuardInterval);
            dvbbasebin.set ("bandwidth", tchannel.Bandwidth);
            dvbbasebin.set ("frequency", tchannel.Frequency);
            dvbbasebin.set ("hierarchy", tchannel.Hierarchy);
            dvbbasebin.set ("inversion", tchannel.Inversion);
            
            return dvbbasebin;
        }
    }

}
