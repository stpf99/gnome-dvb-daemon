using GLib;
using Gst;

namespace DVB {

    public class TerrestrialRecorder : Recorder {
    
        public TerrestrialRecorder (Device dev, ChannelList channels,
            string recordings_base_dir) {
            base.Device = dev;
            base.Channels = channels;
            base.RecordingsBaseDir = recordings_base_dir;
        }
    
        protected override weak Element? get_dvbbasebin (Channel channel) {
            if (!(channel is TerrestrialChannel)) {
                warning("Cannot setup pipeline for non-terrestrial channel");
                return null;
            }
            TerrestrialChannel tchannel = (TerrestrialChannel)channel;
            
            weak Element dvbbasebin = ElementFactory.make ("dvbbasebin", "dvbbasebin");
            dvbbasebin.set ("modulation", tchannel.Constellation);
            dvbbasebin.set ("trans-mode", tchannel.TransmissionMode);
            dvbbasebin.set ("code-rate-hp", tchannel.CodeRateHP);
            dvbbasebin.set ("code-rate-lp", tchannel.CodeRateLP);
            dvbbasebin.set ("guard", tchannel.GuardInterval);
            dvbbasebin.set ("bandwidth", tchannel.Bandwith);
            dvbbasebin.set ("frequency", tchannel.Frequency);
            dvbbasebin.set ("hierarchy", tchannel.Hierarchy);
            
            return dvbbasebin;
        }
    }

}
