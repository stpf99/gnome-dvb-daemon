using GLib;

namespace DVB {

    public class Recorder : GLib.Object {
    
        public signal void recording_started (uint channel);
        public signal void recording_finished ();
        
        public uint AddTimer (uint channel,
            uint start_year, uint start_month, uint start_day,
            uint start_hour, uint start_minute, uint duration) {
            
            return 0;
        }
        
        public bool DeleteTimer (uint timer_id) {
            
            return true;
        }
        
        public uint[] GetTimers () {
        
            return new uint[] {0};
        }
        
        public uint[] GetStartTime (uint timer_id) {
        
            return new uint[] {0};
        }
        
        public uint[] GetEndTime (uint timer_id) {
        
            return new uint[] {0};
        }
        
        public uint GetDuration (uint timer_id) {

            return 0;
        }
        
        public uint[] GetActiveTimers () {
            
            return new uint[] {0};
        }
    
    }

}
