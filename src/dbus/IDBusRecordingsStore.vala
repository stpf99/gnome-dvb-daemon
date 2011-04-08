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

    public struct RecordingInfo {
        public uint32 id;
        public string name;
        public string description;
        public int64 length;
        public int64 start_timestamp;
        public string channel;
        public string location;
    }

    [DBus (name = "org.gnome.DVB.RecordingsStore")]
    public interface IDBusRecordingsStore : GLib.Object {
        
        /**
         * @type: 0: added, 1: deleted, 2: updated
         */
        public abstract signal void changed (uint32 rec_id, uint type);
        
        /**
         * @returns: A list of ids for all recordings
         */
        public abstract uint32[] GetRecordings () throws DBusError;
        
        /**
         * @rec_id: The id of the recording
         * @location: The location of the recording on the filesystem
         * @returns: TRUE on success
         */
        public abstract bool GetLocation (uint32 rec_id, out string location) throws DBusError;
        
        /**
         * @rec_id: The id of the recording
         * @name: The name of the recording (e.g. the name of
         * a TV show)
         * @returns: TRUE on success
         */
        public abstract bool GetName (uint32 rec_id, out string name) throws DBusError;
        
        /**
         * @rec_id: The id of the recording
         * @description: A short text describing the recorded item
         * (e.g. the description from EPG)
         * @returns: TRUE on success
         */
        public abstract bool GetDescription (uint32 rec_id, out string description) throws DBusError;
        
        /**
         * @rec_id: The id of the recording
         * @start_time: The starting time of the recording
         * @returns: TRUE on success
         */
        public abstract bool GetStartTime (uint32 rec_id, out uint[] start_time) throws DBusError;
        
        /**
         * @rec_id: The id of the recording
         * @timestamp: Start time as UNIX timestamp
         * @returns: TRUE on success
         */
        public abstract bool GetStartTimestamp (uint32 rec_id, out int64 timestamp) throws DBusError;
        
        /**
         * @rec_id: The id of the recording
         * @length: The length of the recording in seconds
         * @returns: TRUE on success
         */
        public abstract bool GetLength (uint32 rec_id, out int64 length) throws DBusError;
        
         /**
         * @rec_id: The id of the recording
         * @returns: TRUE on success, FALSE otherwises
         *
         * Delete the recording. This deletes all files in the directory
         * created by the Recorder
         */
        public abstract bool Delete (uint32 rec_id) throws DBusError;
        
        /**
         * @rec_id: The id of the recording
         * @name: The channel's name or an empty string if
         * rec_id doesn't exist
         * @returns: TRUE on success
         */
        public abstract bool GetChannelName (uint32 rec_id, out string name) throws DBusError;
        
        /**
         * @rec_id: The id of the recording
         * @returns: TRUE on success
         *
         * This method can be used to retrieve all informations
         * about a particular recording at once
         */
        public abstract bool GetAllInformations (uint32 rec_id, out RecordingInfo infos) throws DBusError;
        
    }

}
