using GLib;

namespace DVB {

    /**
     * This class represents a frequency and possibly other parameters
     * that are necessary to mark a frequency as scanned
     */
    public class ScannedItem : GLib.Object {

        public uint Frequency {get; construct;}
        private static const int PRIME = 31;
        
        public ScannedItem (uint frequency) {
            this.Frequency = frequency;
        }
        
        public static uint hash (ScannedItem* o) {
            uint hashval;
            // Most specific class first
            if (o is ScannedSatteliteItem) {
                hashval = 2 * PRIME + PRIME * o->Frequency
                    + ((ScannedSatteliteItem)o).Polarization.hash ();
            } else if (o is ScannedItem) {
                hashval = o->Frequency;
            } else {
                hashval = 0;
            }
            return hashval;
        }
        
        public static bool equal (ScannedItem* o1, ScannedItem* o2) {
            if (o1 == null || o2 == null) return false;
            
            if (o1->get_type().name() != o2->get_type().name()) return false;
            
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
                critical ("Don't comparing ScannedItem instances");
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
