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

    [DBus (name = "org.gnome.DVB.RecordingsStore")]
    public interface IDBusRecordingsStore : GLib.Object {
        
        /**
         * @type: 0: added, 1: deleted, 2: updated
         */
        public abstract signal void changed (uint32 rec_id, uint type);
        
        /**
         * @returns: A list of ids for all recordings
         */
        public abstract uint32[] GetRecordings ();
        
        /**
         * @rec_id: The id of the recording
         * @returns: The location of the recording on the filesystem
         */
        public abstract string GetLocation (uint32 rec_id);
        
        /**
         * @rec_id: The id of the recording
         * @returns: The name of the recording (e.g. the name of
         * a TV show)
         */
        public abstract string GetName (uint32 rec_id);
        
        /**
         * @rec_id: The id of the recording
         * @returns: A short text describing the recorded item
         * (e.g. the description from EPG)
         */
        public abstract string GetDescription (uint32 rec_id);
        
        /**
         * @rec_id: The id of the recording
         * @returns: The starting time of the recording
         */
        public abstract uint[] GetStartTime (uint32 rec_id);
        
        /**
         * @rec_id: The id of the recording
         * @returns: Start time as UNIX timestamp
         */
        public abstract int64 GetStartTimestamp (uint32 rec_id);
        
        /**
         * @rec_id: The id of the recording
         * @returns: The length of the recording in seconds
         * or -1 if no recording with the given id exists
         */
        public abstract int64 GetLength (uint32 rec_id);
        
         /**
         * @rec_id: The id of the recording
         * @returns: TRUE on success, FALSE otherwises
         *
         * Delete the recording. This deletes all files in the directory
         * created by the Recorder
         */
        public abstract bool Delete (uint32 rec_id);
        
        /**
         * @rec_id: The id of the recording
         * @returns: The channel's name or an empty string if
         * rec_id doesn't exist
         */
        public abstract string GetChannelName (uint32 rec_id);
        
    }

}
