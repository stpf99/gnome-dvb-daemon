
namespace DVB {

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
