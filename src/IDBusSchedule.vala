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

namespace DVB {

    [DBus (name = "org.gnome.DVB.Schedule")]
    public interface IDBusSchedule : GLib.Object {
    
        public abstract uint32[] GetAllEvents ();
    
        /**
         * @returns: ID of currently running event
         */
        public abstract uint32 NowPlaying ();
        
        /**
         * @returnns: ID of event that follows the given event
         */
        public abstract uint32 Next (uint32 event_id);
        
        public abstract string GetName (uint32 event_id);
        
        public abstract string GetShortDescription (uint32 event_id);
        
        public abstract string GetExtendedDescription (uint32 event_id);
        
        public abstract uint GetDuration (uint32 event_id);
        
        public abstract uint[] GetLocalStartTime (uint32 event_id);
        
        public abstract bool IsRunning (uint32 event_id);
        
        public abstract bool IsScrambled (uint32 event_id);
        /*
        public abstract bool IsHighDefinition (uint32 event_id);
        
        public abstract string GetAspectRatio (uint32 event_id);
        
        public abstract string GetAudioType (uint32 event_id);
        
        public abstract string GetTeletextType (uint32 event_id);
        */
    }

}
