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
