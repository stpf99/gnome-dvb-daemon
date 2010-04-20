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

    public class RecordingWriter : GLib.Object {

        public Recording rec {get; construct;}

        public RecordingWriter (Recording rec) {
            base (rec: rec);
        }

        /**
         * Stores all information of the timer in info.rec
         * in the directory of this.Location
         */
        public void write () throws GLib.Error {
            File parentdir = this.rec.Location.get_parent ();
        
            File recfile = parentdir.get_child ("info.rec");
            
            debug ("Saving recording to %s", recfile.get_path() );
            
            if (recfile.query_exists (null)) {
                debug ("Deleting old info.rec");
                recfile.delete (null);
            }
            
            FileOutputStream stream = recfile.create (0, null);
            
            string text = this.serialize (this.rec);
            stream.write (text, text.size (), null);
            
            stream.close (null);
        }
        
        protected string serialize (Recording rec) {
            uint[] started = rec.get_start ();
            return ("%u\n%s\n%s\n%u-%u-%u %u:%u\n%"+int64.FORMAT+"\n%s\n%s").printf (
                rec.Id, rec.ChannelName, rec.Location.get_path (),                
                started[0], started[1], started[2], started[3],
                started[4], rec.Length,
                (rec.Name == null) ? "" : rec.Name,
                (rec.Description == null) ? "" : rec.Description
            );
        }

    }
        
}
