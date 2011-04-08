/*
 * Copyright (C) 2010 Sebastian Pölsterl
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

namespace DVB.io {

    public class RecordingReader : GLib.Object {

        public File directory {get; construct;}
        public RecordingsStore store {get; construct;}

        private static const string ATTRS = FILE_ATTRIBUTE_STANDARD_TYPE + "," + FILE_ATTRIBUTE_ACCESS_CAN_READ + "," + FILE_ATTRIBUTE_STANDARD_NAME;

        /**
         * @recordingsbasedir: The directory to search
         */
        public RecordingReader (File recordingsbasedir, RecordingsStore recstore) {
            base (directory: recordingsbasedir, store: recstore);
        }

        /**
         * Searches recursively in the given directory
         * for "info.rec" files, restores a new Recording
         * from that file and adds it to itsself.
         */
        public bool load_into () {
            if (!this.directory.query_exists (null)) {
                debug ("Directory %s does not exist", this.directory.get_path ());
                return false;
            }

            return this.restore_from_dir (this.directory);
        }

        private static bool is_readable_dir (File directory) {
            FileInfo info;
            try {
                info = directory.query_info (ATTRS, 0, null);
            } catch (Error e) {
                critical ("Could not retrieve attributes: %s", e.message);
                return false;
            }

            if (info.get_file_type () != FileType.DIRECTORY) {
                critical ("%s is not a directory", directory.get_path ());
                return false;
            }

            if (!info.get_attribute_boolean (FILE_ATTRIBUTE_ACCESS_CAN_READ)) {
                critical ("Cannot read %s", directory.get_path ());
                return false;
            }

            return true;
        }

         
        private bool restore_from_dir (File recordingsbasedir) {
            if (!is_readable_dir (recordingsbasedir)) return false;

            FileEnumerator files;
            try {
                files = recordingsbasedir.enumerate_children (
                    ATTRS, 0, null);
            } catch (Error e) {
                critical ("Could not read directory: %s", e.message);
                return false;
            }

            bool success = true;
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
                                    rec = this.deserialize (child);
                                } catch (Error e) {
                                    critical (
                                        "Could not deserialize recording: %s",
                                        e.message);
                                }
                                if (rec != null) {
                                    debug ("Restored recording from %s",
                                        child.get_path ());
                                    this.store.add_and_monitor (rec);
                                    
                                    
                                }
                            }
                        break;
                    }
                }
            } catch (Error e) {
                critical ("%s", e.message);
                success = false;
            } finally {
                try {
                    files.close (null);
                } catch (Error e) {
                    critical ("Could not close file: %s", e.message);
                    success = false;
                }
            }

            return success;
        }
 
        protected Recording? deserialize (File file) throws Error {
            var reader = new DataInputStream (file.read (null));

            string line = null;
        	size_t len;
        	int line_number = 0;

            var rec = new Recording ();
            StringBuilder description = new StringBuilder ();
        	
        	while ((line = reader.read_line (out len, null)) != null) {
                switch (line_number) {
                    case 0:
                        rec.Id = (uint32)int.parse (line);
                    break;
                    
                    case 1:
                        rec.ChannelName = line;
                    break;
                    
                    case 2:
                        rec.Location = (len == 0) ? null : File.new_for_path (line);
                    break;
                    
                    case 3: {
                        int year = 0;
                        int month = 0;
                        int day = 0;
                        int hour = 0;
                        int minute = 0;
                        line.scanf ("%d-%d-%d %d:%d", &year, &month, &day,
                            &hour, &minute);
                        if (year >= 1900 && month >= 1 && day >= 1 && hour >= 0
                                && minute >= 0) {
                            rec.StartTime = Utils.create_time (year, month, day, hour, minute);
                        }
                    break;
                    }
                    
                    case 4:
                        rec.Length = (int64)int.parse (line);
                    break;
                    
                    case 5:
                        rec.Name = (len == 0) ? null : line;
                    break;
                    
                    default:
                        description.append (line);
                    break;
                }

                line_number++;
        	}
        	reader.close (null);
            rec.Description = description.str;
            
            return rec;
        }
          
    }
}
