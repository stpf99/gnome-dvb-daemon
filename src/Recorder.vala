using GLib;

namespace DVB {

    /**
     * This class is responsible for managing upcoming recordings and
     * already recorded items
     */
    public class Recorder : GLib.Object {
    
        public signal void recording_started (uint timer_id);
        public signal void recording_finished (uint recording_id);
        
        public DVB.Device Device { get; construct; }
        
        protected virtual void start_recording ();
        
        /**
         * @channel: Channel number
         * @start_year: The year when the recording should start
         * @start_month: The month when recording should start
         * @start_day: The day when recording should start
         * @start_hour: The hour when recording should start
         * @start_minute: The minute when recording should start
         * @duration: How long the channel should be recorded
         * @returns: The new timer's id on success
         * 
         * Add a new timer
         */
        public uint AddTimer (uint channel,
            uint start_year, uint start_month, uint start_day,
            uint start_hour, uint start_minute, uint duration) {
            
            return 0;
        }
        
        /**
         * @timer_id: The id of the timer you want to delete
         * @returns: TRUE on success
         *
         * Delete timer
         */
        public bool DeleteTimer (uint timer_id) {
            
            return true;
        }
        
        /**
         * dvb_recorder_GetTimers
         * @returns: A list of all timer ids
         */
        public uint[] GetTimers () {
        
            return new uint[] {0};
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: An array of length 5, where index 0 = year, 1 = month,
         * 2 = day, 3 = hour and 4 = minute.
         */
        public uint[] GetStartTime (uint timer_id) {
        
            return new uint[] {0};
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: Same as dvb_recorder_GetStartTime()
         */
        public uint[] GetEndTime (uint timer_id) {
        
            return new uint[] {0};
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: Duration in seconds
         */
        public uint GetDuration (uint timer_id) {

            return 0;
        }
        
        /**
         * @returns: A list of ids for the currently active timers
         * (i.e.currently active recordings)
         */
        public uint[] GetActiveTimers () {
            
            return new uint[] {0};
        }
        
        /**
         * @returns: TRUE if a timer is already scheduled in the given
         * period of time
         */
        public bool HasTimer (uint start_year, uint start_month,
        uint start_day, uint start_hour, uint start_minute, uint duration) {
        
            return true;
        }
        
        /**
         * @returns: A list of ids for all recordings
         */
        public uint[] GetRecordings () {
            return new uint[] {0};
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: The location of the recording on the filesystem
         */
        public string GetLocationOfRecording (uint rec_id) {
           
            return "";
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: The name of the recording (e.g. the name of
         * a TV show)
         */
        public string GetNameOfRecording (uint rec_id) {
        
            return "";
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: A short text describing the recorded item
         * (e.g. the description from EPG)
         */
        public string GetDescriptionOfRecording (uint rec_id) {
        
            return "";
        }
    
    }

}
