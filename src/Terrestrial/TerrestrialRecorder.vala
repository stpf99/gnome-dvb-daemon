using GLib;
using Gst;

namespace DVB {

    public class TerrestrialRecorder : Recorder {
    
        public TerrestrialRecorder (Device dev) {
            base.Device = dev;
        }
    
        protected override void get_dvbbasebin (Channel channel) {
            if (!(channel is TerrestrialChannel)) {
                warning("Cannot setup pipeline for non-terrestrial channel");
                this.dvbbasebin = null;
            }
            
            TerrestrialChannel tchannel = (TerrestrialChannel)channel;
            
            this.dvbbasebin = ElementFactory.make ("dvbbasebin", "dvbbasebin");
            
            this.dvbbasebin.set ("modulation", tchannel.Constellation);
            this.dvbbasebin.set ("trans-mode", tchannel.TransmissionMode);
            this.dvbbasebin.set ("code-rate-hp", tchannel.CodeRateHP);
            this.dvbbasebin.set ("code-rate-lp", tchannel.CodeRateLP);
            this.dvbbasebin.set ("guard", tchannel.GuardInterval);
            this.dvbbasebin.set ("bandwidth", tchannel.Bandwidth);
            this.dvbbasebin.set ("frequency", tchannel.Frequency);
            this.dvbbasebin.set ("hierarchy", tchannel.Hierarchy);
            this.dvbbasebin.set ("inversion", tchannel.Inversion);
        }
    }

}
