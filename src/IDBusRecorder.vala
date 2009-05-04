/*
 * Copyright (C) 2008,2009 Sebastian Pölsterl
 *
 * This file is part of GNOME DVB Daemon.
 *
 * GNOME DVB Daemon is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * GNOME DVB Daemon is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace DVB {

    [DBus (name = "org.gnome.DVB.Recorder")]
    public interface IDBusRecorder : GLib.Object {
    
        public abstract signal void recording_started (uint32 timer_id);
        public abstract signal void recording_finished (uint32 recording_id);
        
        /**
         * @type: 0: added, 1: deleted, 2: updated
         */
        public abstract signal void changed (uint32 timer_id, uint type);
        
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
         * Works the same way as AddTimer() but adds a margin before and
         * after the timer.
         */
        public abstract uint32 AddTimerWithMargin (uint channel,
            int start_year, int start_month, int start_day,
            int start_hour, int start_minute, uint duration);
        
        /**
         * @event_id: id of the EPG event
         * @channel_sid: SID of channel
         * @returns: The new timer's id on success, or 0 if timer couldn't
         * be created
         */
        public abstract uint32 AddTimerForEPGEvent (uint event_id,
            uint channel_sid);
            
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
         * @timer_id: Timer's id
         * @returns: The name of the channel the timer belongs to or an
         * empty string when a timer with the given id doesn't exist
         */
        public abstract string GetChannelName (uint32 timer_id);
        
        /**
         * @returns: The currently active timers
         */
        public abstract uint32[] GetActiveTimers ();
        
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
        
        /**
         * Checks if a timer overlaps with the given event
         */
        public abstract OverlapType HasTimerForEvent (uint event_id, uint channel_sid);
        
    }

}
