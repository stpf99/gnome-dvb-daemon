namespace DVB {

    [DBus (name = "org.gnome.DVB.Recorder")]
    public interface IDBusRecorder : GLib.Object {
    
        public abstract signal void recording_started (uint32 timer_id);
        public abstract signal void recording_finished (uint32 recording_id);
        public abstract signal void timer_added (uint32 timer_id);
        
        /**
         * @channel: Channel number
         * @start_year: The year when the recording should start
         * @start_month: The month when recording should start
         * @start_day: The day when recording should start
         * @start_hour: The hour when recording should start
         * @start_minute: The minute when recording should start
         * @duration: How long the channel should be recorded (in minutes)
         * @returns: The new timer's id on success, or 0 if timer couldn't
         * be created
         * 
         * Add a new timer
         */
        public abstract uint32 AddTimer (uint channel,
            int start_year, int start_month, int start_day,
            int start_hour, int start_minute, uint duration);
            
        /**
         * @timer_id: The id of the timer you want to delete
         * @returns: TRUE on success
         *
         * Delete timer. If the id belongs to the currently
         * active timer recording is aborted.
         */
        public abstract bool DeleteTimer (uint32 timer_id);
        
        /**
         * dvb_recorder_GetTimers
         * @returns: A list of all timer ids
         */
        public abstract uint32[] GetTimers ();
        
        /**
         * @timer_id: Timer's id
         * @returns: An array of length 5, where index 0 = year, 1 = month,
         * 2 = day, 3 = hour and 4 = minute.
         */
        public abstract uint32[] GetStartTime (uint32 timer_id);
        
        /**
         * @timer_id: Timer's id
         * @returns: Same as dvb_recorder_GetStartTime()
         */
        public abstract uint[] GetEndTime (uint32 timer_id);
        
        /**
         * @timer_id: Timer's id
         * @returns: Duration in seconds or 0 if there's no timer with
         * the given id
         */
        public abstract uint GetDuration (uint32 timer_id);
        
        /**
         * @returns: The currently active timer
         * or 0 if there's no active timer
         */
        public abstract uint32 GetActiveTimer ();
        
        /**
         * @timer_id: Timer's id
         * @returns: TRUE if timer is currently active
         */
        public abstract bool IsTimerActive (uint32 timer_id);
        
        /**
         * @returns: TRUE if a timer is already scheduled in the given
         * period of time
         */
        public abstract bool HasTimer (uint start_year, uint start_month,
            uint start_day, uint start_hour, uint start_minute, uint duration);
        
    }

}
