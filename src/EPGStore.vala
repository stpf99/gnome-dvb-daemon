using GLib;
using Sqlite;
using Gee;

namespace DVB {

    public class EPGStore : GLib.Object {
    
        private static const string CREATE_EVENTS_TABLE_STATEMENT = 
        """CREATE TABLE events (sid INTEGER,
            event_id INTEGER,
            year INTEGER(4),
            month INTEGER(2),
            day INTEGER(2),
            hour INTEGER(2),
            minute INTEGER(2),
            second INTEGER(2),
            duration INTEGER,
            running_status INTEGER(2),
            free_ca_mode INTEGER(1),
            name VARCHAR(255),
            description VARCHAR(255),
            extended_description TEXT,
            PRIMARY KEY (sid, event_id))""";
        
        private static const string INSERT_EVENT_STATEMENT = 
        """INSERT INTO events VALUES ('%u', '%u',
            '%u', '%u', '%u', '%u', '%u', '%u',
            '%u', '%u', '%d', '%s', '%s', '%s')""";
            
        private static const string DELETE_EVENT_STATEMENT = 
            "DELETE FROM events WHERE sid='%u' AND event_id='%u'";
            
        private static const string SELECT_EVENTS_STATEMENT =
            "SELECT * FROM events WHERE sid='%u'";
            
        private static const string HAS_EVENT_STATEMENT =
            "SELECT COUNT(*) FROM events WHERE sid='%u' AND event_id='%u'";
            
        private static const string UPDATE_EVENT_STATEMENT =
            """UPDATE events SET year='%u', month='%u', day='%u', hour='%u',
            minute='%u', second='%u', duration='%u', running_status='%u',
            free_ca_mode='%d', name='%s', description='%s',
            extended_description='%s' WHERE sid='%u' AND event_id='%u'""";
         
        private static EPGStore instance;
        
        private Database db;
            
        construct {
            this.db = this.get_db_handler ();
        }
        
        public static weak EPGStore get_instance () {
            // TODO make thread-safe
            if (instance == null) {
                instance = new EPGStore ();
            }
            return instance;
        }
        
        public bool add_event (Event event, Channel channel) {
            if (this.db == null) {
                critical ("SQLite error: No database connection");
                return false;
            }
        
            int free_ca_mode = (event.free_ca_mode) ? 1 : 0;
            
            string name = escape (event.name);
            string desc = escape (event.description);
            string ext_desc = escape (event.extended_description);
            
            string statement;
            if (this.contains_event (event, channel)) {
                statement = UPDATE_EVENT_STATEMENT.printf (
                    event.year, event.month, event.day, event.hour,
                    event.minute, event.second, event.duration,
                    event.running_status, free_ca_mode, name,
                    desc, ext_desc, channel.Sid, event.id);
            } else {
                statement = INSERT_EVENT_STATEMENT.printf (
                    channel.Sid, event.id,
                    event.year, event.month, event.day, event.hour,
                    event.minute, event.second, event.duration,
                    event.running_status, free_ca_mode, name,
                    desc, ext_desc);
            }
                
            return this.execute (statement);
        }
        
        public bool remove_event (Event event, Channel channel) {
            if (this.db == null) {
                critical ("SQLite error: No database connection");
                return false;
            }
            
            string statement = DELETE_EVENT_STATEMENT.printf (
                channel.Sid, event.id);
            
            return this.execute (statement);
        }
        
        public bool contains_event (Event event, Channel channel) {
            string statement_str = HAS_EVENT_STATEMENT.printf (channel.Sid,
                event.id);
                
            Statement statement;
            if (this.db.prepare (statement_str, -1, out statement) != Sqlite.OK) {
                this.print_last_error ();
                return false;
            }
            
            int c = 0;
            while (statement.step () == Sqlite.ROW) {
                c = statement.column_int (0);
            }
            
            return (c > 0);
        }
        
        public Gee.List<Event> get_events (Channel channel) {
            Gee.List<Event> events = new ArrayList<Event> ();
            
            if (this.db == null) return events;
            
            string statement_str = SELECT_EVENTS_STATEMENT.printf (
                channel.Sid);
            
            Statement statement;
            if (this.db.prepare (statement_str, -1, out statement) != Sqlite.OK) {
                this.print_last_error ();
                return events;
            }
            
            while (statement.step () == Sqlite.ROW) {
                var event = new Event ();
                event.id = (uint)statement.column_int (1);
                event.year = (uint)statement.column_int (2);
                event.month = (uint)statement.column_int (3);
                event.day = (uint)statement.column_int (4);
                event.hour = (uint)statement.column_int (5);
                event.minute = (uint)statement.column_int (6);
                event.second = (uint)statement.column_int (7);
                event.duration = (uint)statement.column_int (8);
                event.running_status = (uint)statement.column_int (9);
                event.free_ca_mode = (statement.column_int (10) == 1);
                // Duplicate strings
                event.name = "%s".printf (statement.column_text (11));
                event.description = "%s".printf (statement.column_text (12));
                event.extended_description = "%s".printf (statement.column_text (13));
                // We don't save those
                event.audio_components = null;
                event.video_components = null;
                event.teletext_components = null;
            }
            
            return events;
        }
        
        private bool execute (string statement) {
            string errormsg;
            int val = this.db.exec (statement, null, null, out errormsg);
            
            if (val != Sqlite.OK) {
                critical ("SQLite error: %s\n%s", errormsg, statement);
                return false;
            }
            return true;
        }
        
        private void print_last_error () {
            critical ("SQLite error: %d, %s",
                this.db.errcode (), this.db.errmsg ());
        }
        
        /**
         * Replace "'" with "''"
         */
        private static string escape (string? text) {
            if (text == null) return "";
        
            Regex regex;
            try {
                regex = new Regex ("'",
                    RegexCompileFlags.MULTILINE,
                    0);
            } catch (RegexError e) {
                warning (e.message);
                return text;
            }
            
            string escaped_str;
            try {
                escaped_str = regex.replace_literal (text, text.size (),
                    0, "''", 0);
            } catch (RegexError e) {
                warning (e.message);
                return text;
            }
            
            return escaped_str;
        }
        
        private Database? get_db_handler () {
            File cache_dir = File.new_for_path (
                Environment.get_user_cache_dir ());
            File our_cache = cache_dir.get_child ("gnome-dvb-daemon");
            File eventsdb = our_cache.get_child ("eventsdb.sqlite3");
           
            if (!our_cache.query_exists (null)) {
                try {
                    Utils.mkdirs (our_cache);
                } catch (Error e) {
                    critical (e.message);
                    return null;
                }
            }
            
            bool create_tables = (!eventsdb.query_exists (null));
            Database db;
            Database.open (eventsdb.get_path (), out db);
            if (create_tables) {
                string errormsg;
                int val = db.exec (CREATE_EVENTS_TABLE_STATEMENT,
                    null, null, out errormsg);
            
                if (val != Sqlite.OK) {
                    critical ("SQLite error: %s", errormsg);
                    return null;
                }
            }
            
            return db;
        }
    
    }

}
