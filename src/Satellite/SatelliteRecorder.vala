using GLib;
using Gst;

namespace DVB {

    public class SatelliteRecorder : Recorder {
    
        public SatelliteRecorder (Device dev, ChannelList channels) {
            base.Device = dev;
            base.Channels = channels;
        }
    
        protected override weak Element? get_dvbbasebin (Channel channel) {
            if (!(channel is SatelliteChannel)) {
                warning("Cannot setup pipeline for non-satellite channel");
                return null;
            }
            SatelliteChannel schannel = (SatelliteChannel)channel;
            
            weak Element dvbbasebin = ElementFactory.make ("dvbbasebin", "dvbbasebin");
            dvbbasebin.set ("frequency", schannel.Frequency);
            dvbbasebin.set ("polarity", schannel.Polarization);
            dvbbasebin.set ("symbol-rate", schannel.SymbolRate);
            dvbbasebin.set ("diseqc-source", schannel.DiseqcSource);
            
            return dvbbasebin;
        }
    }

}
