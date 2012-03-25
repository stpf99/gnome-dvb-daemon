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
using DVB.Logging;

namespace DVB {

    /**
     * This class represents a finished recording
     */
    public class Recording : GLib.Object {

        private static Logger log = LogManager.getLogManager().getDefaultLogger();

        public uint32 Id {get; set;}
        public uint ChannelSid {get; set;}
        public string ChannelName {get; set;}
        public File Location {get; set;}
        public string? Name {get; set;}
        public string? Description {get; set;}
        public GLib.Time StartTime {get; set;}
        public int64 Length {get; set;}
        public FileMonitor file_monitor {get; set;}

        public uint[] get_start () {
            return new uint[] {
                this.StartTime.year + 1900,
                this.StartTime.month + 1,
                this.StartTime.day,
                this.StartTime.hour,
                this.StartTime.minute
            };
        }

        public void monitor_recording () {
            try {
                this.file_monitor = this.Location.monitor_file (0, null);
                this.file_monitor.changed.connect (this.on_recording_file_changed);
            } catch (Error e) {
                warning ("Could not create FileMonitor: %s", e.message);
            }
        }

        public void save_to_disk () {
            var writer = new io.RecordingWriter (this);
            try {
                writer.write ();
            } catch (Error e) {
                log.error ("Could not save recording: %s", e.message);
            }
        }

        private void on_recording_file_changed (FileMonitor monitor,
                File file, File? other_file, FileMonitorEvent event) {
            if (event == FileMonitorEvent.DELETED) {
                string location = file.get_path ();
                log.debug ("%s has been deleted", location);

                monitor.cancel ();

                RecordingsStore.get_instance().remove (this);
            }
        }
    }

}
