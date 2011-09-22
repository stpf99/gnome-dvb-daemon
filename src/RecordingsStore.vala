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

using GLib;
using Gee;
using DVB.Logging;

namespace DVB {

    /**
     * This class manages the recordings off all devices
     */
    public class RecordingsStore : GLib.Object, IDBusRecordingsStore {

        private static Logger log = LogManager.getLogManager().getDefaultLogger();
    
        private HashMap<uint32, Recording> recordings;
        private uint32 last_id;
        private static RecordingsStore instance;
        private static StaticRecMutex instance_mutex = StaticRecMutex ();
        
        construct {
            this.recordings = new HashMap <uint32, Recording> ();
            this.last_id = 0;
        }
        
        public static unowned RecordingsStore get_instance () {
            instance_mutex.lock ();
            if (instance == null) {
                instance = new RecordingsStore ();
            }
            instance_mutex.unlock ();
            return instance;
        }
        
        public static void shutdown () {
            instance_mutex.lock ();
            RecordingsStore rs = instance;
            if (rs != null) {
                rs.recordings.clear ();
                instance = null;
            }
            instance_mutex.unlock ();
        }

        public void update_last_id (uint32 new_last_id) {
            lock (this.recordings) {
                if (new_last_id > this.last_id)
                    this.last_id = new_last_id;
            }
        }

        public bool add (Recording rec) {
            uint32 id = rec.Id;
            lock (this.recordings) {
                if (this.recordings.has_key (id)) {
                    log.error ("Recording with id %u already available", id);
                    return false;
                }

                if (rec.Id > this.last_id) {
                    this.last_id = rec.Id;
                }

                this.recordings.set (id, rec);
                this.changed (id, ChangeType.ADDED);
            }
            return true;
        }
        
        public bool add_and_monitor (Recording rec) {
            if (this.add (rec)) {
                rec.monitor_recording ();
                return true;
            }
            return false;
        }

        public void remove (Recording rec) {
            uint32 rec_id = rec.Id;
            this.recordings.unset (rec_id);
            this.changed (rec_id, ChangeType.DELETED);
        }

        public uint32 get_next_id () {
            uint32 val;
            lock (this.recordings) {
                val = (++this.last_id);
            }
            return val;
        }
        
        /**
         * @returns: A list of ids for all recordings
         */
        public uint32[] GetRecordings () throws DBusError {
            uint32[] ids;
            lock (this.recordings) {
                ids = new uint32[this.recordings.size];
                
                int i = 0;
                foreach (uint32 key in this.recordings.keys) {
                    ids[i] = key;
                    i++;
                }
            }
            
            return ids;
        }
        
        /**
         * @rec_id: The id of the recording
         * @location: The location of the recording on the filesystem
         * @returns: TRUE on success
         */
        public bool GetLocation (uint32 rec_id, out string location) throws DBusError {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.has_key (rec_id)) {
                    location = this.recordings.get(rec_id).Location.get_uri ();
                    ret = true;
                } else {
                    location = "";
                }
            }

            return ret;
        }
        
        /**
         * @rec_id: The id of the recording
         * @name: The name of the recording (e.g. the name of
         * a TV show)
         * @returns: TRUE on success
         */
        public bool GetName (uint32 rec_id, out string name) throws DBusError {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.has_key (rec_id)) {
                    string val = this.recordings.get(rec_id).Name;
                    name = (val == null) ? "" : val;
                    ret = true;
                } else {
                    name = "";
                }
            }

            return ret;
        }
        
        /**
         * @rec_id: The id of the recording
         * @description: A short text describing the recorded item
         * (e.g. the description from EPG)
         * @returns: TRUE on success
         */
        public bool GetDescription (uint32 rec_id, out string description) throws DBusError {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.has_key (rec_id)) {
                    string val = this.recordings.get(rec_id).Description;
                    description = (val == null) ? "" : val;
                    ret = true;
                } else {
                    description = "";
                }
            }

            return ret;
        }
        
        /**
         * @rec_id: The id of the recording
         * @start_time: The starting time of the recording
         * @returns: TRUE on success
         */
        public bool GetStartTime (uint32 rec_id, out uint[] start_time) throws DBusError {
            bool ret;
            lock (this.recordings) {
                if (this.recordings.has_key (rec_id)) {
                    start_time = this.recordings.get(rec_id).get_start ();
                    ret = true;
                } else {
                    start_time = new uint[] {};
                    ret = false;
                }
            }

            return ret;
        }
        
        /**
         * @rec_id: The id of the recording
         * @timestamp: Start time as UNIX timestamp
         * @returns: TRUE on success
         */
        public bool GetStartTimestamp (uint32 rec_id, out int64 timestamp) throws DBusError {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.has_key (rec_id)) {
                    timestamp = (int64)this.recordings.get(rec_id).StartTime.mktime ();
                    ret = true;
                } else {
                    timestamp = 0;
                }
            }
            
            return ret;
        }
        
        /**
         * @rec_id: The id of the recording
         * @length: The length of the recording in seconds
         * @returns: TRUE on success
         */
        public bool GetLength (uint32 rec_id, out int64 length) throws DBusError {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.has_key (rec_id)) {
                    length = this.recordings.get(rec_id).Length;
                    ret = true;
                } else {
                    length = 0;
                }
            }
           
            return ret;
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: TRUE on success, FALSE otherwises
         *
         * Delete the recording. This deletes all files in the directory
         * created by the Recorder
         */
        public bool Delete (uint32 rec_id) throws DBusError {
            bool val = false;
            lock (this.recordings) {
                if (!this.recordings.has_key (rec_id)) val = false;
                else {
                    log.debug ("Deleting recording %u", rec_id);
                    var rec = this.recordings.get (rec_id);
                    try {
                        Utils.delete_dir_recursively (rec.Location.get_parent ());
                        val = true;
                    } catch (Error e) {
                        log.error ("Could not delete recording: %s", e.message);
                        val = false;
                    }
                    this.remove (rec);
                }
            }
            
            return val;
        }
        
        /**
         * @rec_id: The id of the recording
         * @name: The channel's name or an empty string if
         * rec_id doesn't exist
         * @returns: TRUE on success
         */
        public bool GetChannelName (uint32 rec_id, out string name) throws DBusError {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.has_key (rec_id)) {
                    Recording rec = this.recordings.get (rec_id);
                    name = rec.ChannelName;
                    ret = true;
                } else {
                    name = "";
                }
            }

            return ret;
        }
        
        public bool GetAllInformations (uint32 rec_id, out RecordingInfo info) throws DBusError {
            bool ret;
            info = RecordingInfo ();
            lock (this.recordings) {
                if (this.recordings.has_key (rec_id)) {
                    Recording rec = this.recordings.get (rec_id);
                    string name = rec.Name;
                    info.name = (name == null) ? "" : name;
                    info.id = rec_id;
                    info.length = rec.Length;
                    info.description = (rec.Description == null) ? "" : rec.Description;
                    info.location = rec.Location.get_path ();
                    info.start_timestamp = (int64)rec.StartTime.mktime ();
                    info.channel = rec.ChannelName;
                    ret = true;
                } else {
                    info.name = "";
                    info.id = 0;
                    info.length = 0;
                    info.description = "";
                    info.location = "";
                    info.start_timestamp = 0;
                    info.channel = "";
                    ret = false;
                }
            }
            return ret;
        }

        public void restore_from_dir (File recordingsbasedir) {
            var reader = new io.RecordingReader (recordingsbasedir, this);
            reader.load_into ();
        }

    }
    
}
