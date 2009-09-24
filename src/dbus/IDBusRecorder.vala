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

    public struct TimerInfo {
        public uint32 id;
        public uint duration;
        public bool active;
        public string channel_name;
        public string title;
    }

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
         * @timer_id: The new timer's id on success, or 0 if timer couldn't
         * be created
         * @returns: TRUE on success
         * 
         * Add a new timer
         */
        public abstract bool AddTimer (uint channel,
            int start_year, int start_month, int start_day,
            int start_hour, int start_minute, uint duration, out uint32 timer_id) throws DBus.Error;
        
         /**
         * Works the same way as AddTimer() but adds a margin before and
         * after the timer.
         */
        public abstract bool AddTimerWithMargin (uint channel,
            int start_year, int start_month, int start_day,
            int start_hour, int start_minute, uint duration, out uint32 timer_id) throws DBus.Error;
        
        /**
         * @event_id: id of the EPG event
         * @channel_sid: SID of channel
         * @timer_id: The new timer's id on success, or 0 if timer couldn't
         * be created
         * @returns: TRUE on success
         */
        public abstract bool AddTimerForEPGEvent (uint event_id,
            uint channel_sid, out uint32 timer_id) throws DBus.Error;
            
        /**
         * @timer_id: The id of the timer you want to delete
         * @returns: TRUE on success
         *
         * Delete timer. If the id belongs to the currently
         * active timer recording is aborted.
         */
        public abstract bool DeleteTimer (uint32 timer_id) throws DBus.Error;
        
        /**
         * dvb_recorder_GetTimers
         * @returns: A list of all timer ids
         */
        public abstract uint32[] GetTimers () throws DBus.Error;
        
        /**
         * @timer_id: Timer's id
         * @start_time: An array of length 5, where index 0 = year, 1 = month,
         * 2 = day, 3 = hour and 4 = minute.
         * @returns: TRUE on success
         */
        public abstract bool GetStartTime (uint32 timer_id, out uint32[] start_time) throws DBus.Error;
        
        /**
         * @timer_id: Timer's id
         * @end_time: Same as dvb_recorder_GetStartTime()
         * @returns: TRUE on success
         */
        public abstract bool GetEndTime (uint32 timer_id, out uint[] end_time) throws DBus.Error;
        
        /**
         * @timer_id: Timer's id
         * @duration: Duration in seconds or 0 if there's no timer with
         * the given id
         * @returns: TRUE on success
         */
        public abstract bool GetDuration (uint32 timer_id, out uint duration) throws DBus.Error;
        
        /**
         * @timer_id: Timer's id
         * @name: The name of the channel the timer belongs to or an
         * empty string when a timer with the given id doesn't exist
         * @returns: TRUE on success
         */
        public abstract bool GetChannelName (uint32 timer_id, out string name) throws DBus.Error;

        /**
         * @timer_id: Timer's id
         * @title: The name of the show the timer belongs to or an
         * empty string if the timer doesn't exist or has no information
         * about the title of the show
         * @returns: TRUE on success
         */
        public abstract bool GetTitle (uint32 timer_id, out string title) throws DBus.Error;

        /**
         * @timer_id: Timer's id
         * @returns: TRUE on success
         *
         * This method can be used to retrieve all informations
         * about a particular timer at once
         */
        public abstract bool GetAllInformations (uint32 timer_id, out TimerInfo info) throws DBus.Error;
        
        /**
         * @returns: The currently active timers
         */
        public abstract uint32[] GetActiveTimers () throws DBus.Error;
        
        /**
         * @timer_id: Timer's id
         * @returns: TRUE if timer is currently active
         */
        public abstract bool IsTimerActive (uint32 timer_id) throws DBus.Error;
        
        /**
         * @returns: TRUE if a timer is already scheduled in the given
         * period of time
         */
        public abstract bool HasTimer (uint start_year, uint start_month,
            uint start_day, uint start_hour, uint start_minute, uint duration) throws DBus.Error;
        
        /**
         * Checks if a timer overlaps with the given event
         */
        public abstract OverlapType HasTimerForEvent (uint event_id, uint channel_sid) throws DBus.Error;
        
    }

}
