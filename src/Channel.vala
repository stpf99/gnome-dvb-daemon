using GLib;

namespace DVB {

    public class Channel : GLib.Object {

        public uint Sid {get; construct;}
        public string Name {get; set;}
        public uint TransportStreamId {get; set;}
        public string Network {get; set;}
        public uint? LogicalChannelNumber {get; set;}
        public uint VideoPID {get; set;}
        public uint AudioPID {get; set;}
        public uint Frequency {get; set;}
        
        public Channel (uint sid) {
            this.Sid = sid;
        }

    }
    
    public class SatelliteChannel : Channel {
        
        public string Polarization {get; set;}
        public uint SymbolRate {get; set;}
        
    }
    
    public class CableChannel : Channel {
    
        public DvbSrcInversion Inversion {get; set;}
        public uint SymbolRate {get; set;}
        // TODO: FEC, Modulation
    
    }
    
    public class TerrestrialChannel : Channel {
    
        public DvbSrcInversion Inversion {get; set;}
        public DvbSrcBandwidth Bandwith {get; set;}
        public DvbSrcCodeRate CodeRateHP {get; set;}
        public DvbSrcCodeRate CodeRateLP {get; set;}
        public string Constallation {get; set;}
        public DvbSrcTransmissionMode TransmissionMode {get; set;}
        public DvbSrcGuard GuardInterval {get; set;}
        public DvbSrcHierarchy Hierarchy {get; set;}
    
    }
    
}
