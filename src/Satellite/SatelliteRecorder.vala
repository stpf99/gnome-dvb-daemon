using GLib;
using Gst;

namespace DVB {

    public class SatelliteRecorder : Recorder {
    
        public SatelliteRecorder (Device dev) {
            base.Device = dev;
        }
    
        protected override void get_dvbbasebin (Channel channel) {
            if (!(channel is SatelliteChannel)) {
                warning("Cannot setup pipeline for non-satellite channel");
                this.dvbbasebin = null;
            }
            SatelliteChannel schannel = (SatelliteChannel)channel;
            
            this.dvbbasebin = ElementFactory.make ("dvbbasebin", "dvbbasebin");
            this.dvbbasebin.set ("frequency", schannel.Frequency);
            this.dvbbasebin.set ("polarity", schannel.Polarization);
            this.dvbbasebin.set ("symbol-rate", schannel.SymbolRate);
            this.dvbbasebin.set ("diseqc-source", schannel.DiseqcSource);
        }
    }

}
