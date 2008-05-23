
namespace DVB {

    public class CableChannel : Channel {
    
        public DvbSrcInversion Inversion {get; set;}
        public uint SymbolRate {get; set;}
        // TODO: FEC, Modulation
    
    }
    
}
