using GLib;

namespace DVB {

    public class ScannedItem : GLib.Object {

        public uint Frequency {get; construct;}
        
        public ScannedItem (uint frequency) {
            this.Frequency = frequency;
        }
        
        public static bool equal (void* a, void* b) {
            if (a == null || b == null) return false;
            Object o1 = (Object)a;
            Object o2 = (Object)b;
            
            if (o1.get_type() != o2.get_type()) return false;
            
            if (o1 is ScannedSatteliteItem) {
                ScannedSatteliteItem item1 = (ScannedSatteliteItem)o1;
                ScannedSatteliteItem item2 = (ScannedSatteliteItem)o2;
                
                return ((ScannedItem)item1).Frequency == ((ScannedItem)item2).Frequency
                    && item1.Polarization == item2.Polarization;
            } else if (o1 is ScannedItem) {
                ScannedItem item1 = (ScannedItem)o1;
                ScannedItem item2 = (ScannedItem)o2;
                
                return (item1.Frequency == item2.Frequency);
            } else {
                warning("Don't comparing ScannedItem instances");
                return false;
            }
        }
    }

    public class ScannedSatteliteItem : ScannedItem {

        public string Polarization {get; construct;}
        
        public ScannedSatteliteItem (uint frequency, string polarization) {
            this.Frequency = frequency;
            this.Polarization = polarization;
        }
    }
    
}
