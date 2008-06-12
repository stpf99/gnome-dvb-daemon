using GLib;

namespace DVB {

    public class EPGStore : GLib.Object {
    
        public uint32[] NowPlaying () {
            return new uint32[] {};
        }
        
        public uint32[] Next () {
            return new uint32[] {};
        }
        
        public string GetName (uint32 event_id) {
            return "";
        }
        
        public string GetShortDescription (uint32 event_id) {
            return "";   
        }
        
        public string GetExtendedDescription (uint32 event_id) {
            return "";
        }
        
        public uint GetDuration (uint32 event_id) {
            return 0;
        }
        
        public uint[] GetLocalStartTime (uint32 event_id) {
            return new uint[] {};
        }
        
        public bool IsHighDefinition (uint32 event_id) {
            return true;
        }
        
        public string GetAspectRatio (uint32 event_id) {
            return "";
        }
        
        public bool IsRunning (uint32 event_id) {
            return true;
        }
        
        public string GetAudioType (uint32 event_id) {
            return "";
        }
        
        public string GetTeletextType (uint32 event_id) {
            return "";
        }
    
    }

}
