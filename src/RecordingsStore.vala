using GLib;
using Gee;

namespace DVB {

    /**
     * This class manages the recordings off all devices
     */
    public class RecordingsStore : GLib.Object {
    
        private HashMap<uint32, Recording> recordings;
        private uint32 last_id;
        private static RecordingsStore instance;
        
        construct {
            this.recordings = new HashMap <uint32, Recording> ();
            this.last_id = 0;
        }
        
        public static weak RecordingsStore get_instance () {
            if (instance == null) {
                instance = new RecordingsStore ();
            }
            return instance;
        }
        
        public bool add (Recording rec) {
            uint32 id = rec.Id;
            if (this.recordings.contains (id)) {
                critical ("Recording with id %s already available", id);
                return false;
            }
            
            this.recordings.set (id, rec);
            return true;
        }
    
        public uint32 get_next_id () {
            return (++this.last_id);
        }
        
        /**
         * @returns: A list of ids for all recordings
         */
        public uint32[] GetRecordings () {
            uint32[] ids = new uint32[this.recordings.size];
            
            int i = 0;
            foreach (uint32 key in this.recordings.get_keys ()) {
                ids[i] = key;
                i++;
            }
            
            return ids;
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: The location of the recording on the filesystem
         */
        public string? GetLocation (uint32 rec_id) {
            string? val = null;
            if (this.recordings.contains (rec_id)) {
                val = this.recordings.get(rec_id).Location.get_path ();
            }
           
            return val;
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: The name of the recording (e.g. the name of
         * a TV show)
         */
        public string? GetName (uint32 rec_id) {
            string? val = null;
            if (this.recordings.contains (rec_id)) {
                val = this.recordings.get(rec_id).Name;
            }
           
            return val;
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: A short text describing the recorded item
         * (e.g. the description from EPG)
         */
        public string? GetDescription (uint32 rec_id) {
            string? val = null;
            if (this.recordings.contains (rec_id)) {
                val = this.recordings.get(rec_id).Description;
            }
           
            return val;
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: The starting time of the recording
         */
        public uint[]? GetStartTime (uint32 rec_id) {
            uint[]? val = null;
            if (this.recordings.contains (rec_id)) {
                val = this.recordings.get(rec_id).get_start ();
            }
           
            return val;
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: The length of the recording in seconds
         * or -1 if no recording with the given id exists
         */
        public int64 GetLength (uint32 rec_id) {
            int64 val = -1;
            if (this.recordings.contains (rec_id)) {
                val = this.recordings.get(rec_id).Length;
            }
           
            return val;
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: TRUE on success, FALSE otherwises
         *
         * Delete the recording. This deletes all files in the directory
         * created by the Recorder
         */
        public bool Delete (uint32 rec_id) {
            bool val = false;
            if (!this.recordings.contains (rec_id)) val = false;
            else {
                var rec = this.recordings.get (rec_id);
                try {
                    Utils.delete_dir_recursively (rec.Location.get_parent ());
                    this.recordings.remove (rec_id);
                    val = true;
                } catch (Error e) {
                    critical (e.message);
                    val = false;
                }
            }
            
            return val;
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
                critical ("Directory %s does not exist", recordingsbasedir.get_path ());
                return;
            }
            
            string attrs = "%s,%s,%s".printf (FILE_ATTRIBUTE_STANDARD_TYPE,
                FILE_ATTRIBUTE_ACCESS_CAN_READ, FILE_ATTRIBUTE_STANDARD_NAME);
            FileInfo info;
            try {
                info = recordingsbasedir.query_info (attrs, 0, null);
            } catch (Error e) {
                critical (e.message);
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
                critical (e.message);
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
                                Recording rec;
                                try {
                                    rec = Recording.deserialize (child);
                                } catch (Error e) {
                                    critical (e.message);
                                }
                                if (rec != null) {
                                    debug ("Restored timer from %s", child.get_path ());
                                    this.add (rec);
                                    if (rec.Id > this.last_id)
                                        this.last_id = rec.Id;
                                }
                            }
                        break;
                    }
                }
            } catch (Error e) {
                critical (e.message);
            } finally {
                try {
                    files.close (null);
                } catch (Error e) {
                    critical (e.message);
                }
            }
        }
    
    }
    
}
