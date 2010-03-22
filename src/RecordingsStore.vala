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

namespace DVB {

    /**
     * This class manages the recordings off all devices
     */
    public class RecordingsStore : GLib.Object, IDBusRecordingsStore {
    
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
            lock (this.last_id) {
                if (new_last_id > this.last_id)
                    this.last_id = new_last_id;
            }
        }
        
        public bool add (Recording rec, bool monitor) {
            uint32 id = rec.Id;
            lock (this.recordings) {
                if (this.recordings.contains (id)) {
                    critical ("Recording with id %u already available", id);
                    return false;
                }

                if (monitor) {
                    this.monitor_recording (rec);
                }
                
                this.recordings.set (id, rec);
                this.changed (id, ChangeType.ADDED);
            }
            return true;
        }
        
        public void monitor_recording (Recording rec) {
            // Monitor the recording
            try {
                FileMonitor monitor = rec.Location.monitor_file (0, null);
                monitor.changed += this.on_recording_file_changed;
                rec.file_monitor = monitor;
            } catch (Error e) {
                warning ("Could not create FileMonitor: %s", e.message);
            }
        }
    
        public uint32 get_next_id () {
            uint32 val;
            lock (this.last_id) {
                val = (++this.last_id);
            }
            return val;
        }
        
        /**
         * @returns: A list of ids for all recordings
         */
        public uint32[] GetRecordings () throws DBus.Error {
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
        public bool GetLocation (uint32 rec_id, out string location) throws DBus.Error {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.contains (rec_id)) {
                    location = this.recordings.get(rec_id).Location.get_uri ();
                    ret = true;
                }
            }
            if (!ret) location = "";
            return ret;
        }
        
        /**
         * @rec_id: The id of the recording
         * @name: The name of the recording (e.g. the name of
         * a TV show)
         * @returns: TRUE on success
         */
        public bool GetName (uint32 rec_id, out string name) throws DBus.Error {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.contains (rec_id)) {
                    string val = this.recordings.get(rec_id).Name;
                    name = (val == null) ? "" : val;
                    ret = true;
                }
            }
            if (!ret) name = "";
            return ret;
        }
        
        /**
         * @rec_id: The id of the recording
         * @description: A short text describing the recorded item
         * (e.g. the description from EPG)
         * @returns: TRUE on success
         */
        public bool GetDescription (uint32 rec_id, out string description) throws DBus.Error {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.contains (rec_id)) {
                    string val = this.recordings.get(rec_id).Description;
                    description = (val == null) ? "" : val;
                    ret = true;
                }
            }
            if (!ret) description = "";
            return ret;
        }
        
        /**
         * @rec_id: The id of the recording
         * @start_time: The starting time of the recording
         * @returns: TRUE on success
         */
        public bool GetStartTime (uint32 rec_id, out uint[] start_time) throws DBus.Error {
            bool ret;
            lock (this.recordings) {
                if (this.recordings.contains (rec_id)) {
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
        public bool GetStartTimestamp (uint32 rec_id, out int64 timestamp) throws DBus.Error {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.contains (rec_id)) {
                    timestamp = (int64)this.recordings.get(rec_id).StartTime.mktime ();
                    ret = true;
                }
            }
            
            return ret;
        }
        
        /**
         * @rec_id: The id of the recording
         * @length: The length of the recording in seconds
         * @returns: TRUE on success
         */
        public bool GetLength (uint32 rec_id, out int64 length) throws DBus.Error {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.contains (rec_id)) {
                    length = this.recordings.get(rec_id).Length;
                    ret = true;
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
        public bool Delete (uint32 rec_id) throws DBus.Error {
            bool val = false;
            lock (this.recordings) {
                if (!this.recordings.contains (rec_id)) val = false;
                else {
                    debug ("Deleting recording %u", rec_id);
                    var rec = this.recordings.get (rec_id);
                    try {
                        Utils.delete_dir_recursively (rec.Location.get_parent ());
                        this.recordings.remove (rec_id);
                        val = true;
                    } catch (Error e) {
                        critical ("Could not delete recording: %s", e.message);
                        val = false;
                    }
                    this.changed (rec_id, ChangeType.DELETED);
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
        public bool GetChannelName (uint32 rec_id, out string name) throws DBus.Error {
            bool ret = false;
            lock (this.recordings) {
                if (this.recordings.contains (rec_id)) {
                    Recording rec = this.recordings.get (rec_id);
                    name = rec.ChannelName;
                    ret = true;
                }
            }
            if (!ret) name = "";
            return ret;
        }
        
        public bool GetAllInformations (uint32 rec_id, out RecordingInfo info) throws DBus.Error {
            bool ret;
            info = RecordingInfo ();
            lock (this.recordings) {
                if (this.recordings.contains (rec_id)) {
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
        
        /**
         * @recordingsbasedir: The directory to search
         *
         * Searches recursively in the given directory
         * for "info.rec" files, restores a new Recording
         * from that file and adds it to itsself.
         */
        public void restore_from_dir (File recordingsbasedir) {
            if (!recordingsbasedir.query_exists (null)) {
                debug ("Directory %s does not exist", recordingsbasedir.get_path ());
                return;
            }
            
            string attrs = "%s,%s,%s".printf (FILE_ATTRIBUTE_STANDARD_TYPE,
                FILE_ATTRIBUTE_ACCESS_CAN_READ, FILE_ATTRIBUTE_STANDARD_NAME);
            FileInfo info;
            try {
                info = recordingsbasedir.query_info (attrs, 0, null);
            } catch (Error e) {
                critical ("Could not retrieve attributes: %s", e.message);
                return;
            }
           
            if (info.get_file_type () != FileType.DIRECTORY) {
                critical ("%s is not a directory", recordingsbasedir.get_path ());
                return;
            }
            
            if (!info.get_attribute_boolean (FILE_ATTRIBUTE_ACCESS_CAN_READ)) {
                critical ("Cannot read %s", recordingsbasedir.get_path ());
                return;
            }
        
            FileEnumerator files;
            try {
                files = recordingsbasedir.enumerate_children (
                    attrs, 0, null);
            } catch (Error e) {
                critical ("Could not read directory: %s", e.message);
                return;
            }
            
            try {
                FileInfo childinfo;
                while ((childinfo = files.next_file (null)) != null) {
                    uint32 type = childinfo.get_attribute_uint32 (
                        FILE_ATTRIBUTE_STANDARD_TYPE);
                    
                    File child = recordingsbasedir.get_child (
                        childinfo.get_name ());
                    
                    switch (type) {
                        case FileType.DIRECTORY:
                            this.restore_from_dir (child);
                        break;
                        
                        case FileType.REGULAR:
                            if (childinfo.get_name () == "info.rec") {
                                Recording rec = null;
                                try {
                                    rec = Recording.deserialize (child);
                                } catch (Error e) {
                                    critical (
                                        "Could not deserialize recording: %s",
                                        e.message);
                                }
                                if (rec != null) {
                                    debug ("Restored recording from %s",
                                        child.get_path ());
                                    lock (this.recordings) {
                                        this.add (rec, true);
                                    }
                                    
                                    lock (this.last_id) {
                                        if (rec.Id > this.last_id) {
                                            this.last_id = rec.Id;
                                        }
                                    }
                                }
                            }
                        break;
                    }
                }
            } catch (Error e) {
                critical ("%s", e.message);
            } finally {
                try {
                    files.close (null);
                } catch (Error e) {
                    critical ("Could not close file: %s", e.message);
                }
            }
        }
        
        /**
         * @location: Path to the .ts file of the recording
         * @returns: TRUE on success
         *
         * Delete a recording by the path of the recording
         */
        private bool delete_recording_by_location (string location) {
            bool result = false;
            uint32 rec_id = 0;
            lock (this.recordings) {
                foreach (uint32 id  in this.recordings.keys) {
                    Recording rec = this.recordings.get (id);
                    if (rec.Location.get_path () == location) {
                        rec_id = id;
                        break;
                    }
                }
                
                if (rec_id != 0) {
                    debug ("Deleting recording %u", rec_id);
                    this.recordings.remove (rec_id);
                    this.changed (rec_id, ChangeType.DELETED);
                    result = true;
                }
            }
            
            return result;
        }
        
        private void on_recording_file_changed (FileMonitor monitor,
                File file, File? other_file, FileMonitorEvent event) {
            if (event == FileMonitorEvent.DELETED) {
                string location = file.get_path ();
                debug ("%s has been deleted", location);
                this.delete_recording_by_location (location);
                
                monitor.cancel ();
            }
        }
    
    }
    
}
