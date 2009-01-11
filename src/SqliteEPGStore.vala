using GLib;
using Sqlite;
using Gee;

namespace DVB {

    public class SqliteEPGStore : GLib.Object, EPGStore {
    
        private static const string CREATE_EVENTS_TABLE_STATEMENT = 
            """CREATE TABLE events (sid INTEGER,
            event_id INTEGER,
            starttime JULIAN,
            duration INTEGER,
            running_status INTEGER(2),
            free_ca_mode INTEGER(1),
            name VARCHAR(255),
            description VARCHAR(255),
            extended_description TEXT,
            PRIMARY KEY (sid, event_id))""";
        
        private static const string INSERT_EVENT_SQL = 
            "INSERT INTO events VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
            
        private static const string DELETE_EVENT_STATEMENT = 
            "DELETE FROM events WHERE sid=? AND event_id=?";
            
        private static const string SELECT_ALL_EVENTS_STATEMENT =
            """SELECT event_id, datetime(starttime),
            duration, running_status, free_ca_mode, name,
            description, extended_description
            FROM events WHERE sid='%u'""";
            
        private static const string HAS_EVENT_STATEMENT =
            "SELECT COUNT(*) FROM events WHERE sid=? AND event_id=?";
            
        private static const string UPDATE_EVENT_SQL =
            """UPDATE events SET starttime=?, duration=?, running_status=?,
            free_ca_mode=?, name=?, description=?,
            extended_description=? WHERE sid=? AND event_id=?""";
            
        private static const string TO_JULIAN_SQL =
            "SELECT julianday(?)";
            
        private static const string SELECT_EVENT_SQL =
            """SELECT event_id, datetime(starttime),
            duration, running_status, free_ca_mode, name,
            description, extended_description
            FROM events WHERE sid=? AND event_id=?""";
            
        private Statement to_julian_statement;
        private Statement insert_event_statement;
        private Statement update_event_statement;
        private Statement delete_event_statement;
        private Statement has_event_statement;
        private Statement select_event_statement;
        
        // Database must be the last parameter, because the statements
        // MUST be finalized first before the database is closed
        private Database db;
            
        construct {
            this.db = get_db_handler ();
            
            this.db.prepare (TO_JULIAN_SQL, -1,
                out this.to_julian_statement);
            this.db.prepare (INSERT_EVENT_SQL, -1,
                out this.insert_event_statement);
            this.db.prepare (UPDATE_EVENT_SQL, -1,
                out this.update_event_statement);
            this.db.prepare (DELETE_EVENT_STATEMENT, -1,
                out this.delete_event_statement);
            this.db.prepare (HAS_EVENT_STATEMENT, -1,
                out this.has_event_statement);
            this.db.prepare (SELECT_EVENT_SQL, -1,
                out this.select_event_statement);
        }
        
        public bool add_or_update_event (Event event, Channel channel) {
            if (this.db == null) {
                critical ("SQLite error: No database connection");
                return false;
            }
        
            int free_ca_mode = (event.free_ca_mode) ? 1 : 0;
            
            string name = escape (event.name);
            string desc = escape (event.description);
            string ext_desc = escape (event.extended_description);
            double julian_start = this.to_julian (event.year, event.month,
                event.day, event.hour, event.minute, event.second);
            
            // Check if start time got converted correctly
            if (julian_start <= 0) return false;
            
            if (this.contains_event (event, channel)) {
                this.update_event_statement.reset ();
                
                if (this.update_event_statement.bind_double (1, julian_start) != Sqlite.OK
                        || this.update_event_statement.bind_int (2, (int)event.duration) != Sqlite.OK
                        || this.update_event_statement.bind_int (3, (int)event.running_status) != Sqlite.OK
                        || this.update_event_statement.bind_int (4, free_ca_mode) != Sqlite.OK
                        || this.update_event_statement.bind_text (5, name) != Sqlite.OK
                        || this.update_event_statement.bind_text (6, desc) != Sqlite.OK
                        || this.update_event_statement.bind_text (7, ext_desc) != Sqlite.OK) {
                    this.print_last_error ();
                    return false;
                }
                
                if (this.update_event_statement.step () != Sqlite.DONE) {
                    this.print_last_error ();
                    return false;
                }
            } else {
                this.insert_event_statement.reset ();
                
                if (this.insert_event_statement.bind_int (1, (int)channel.Sid) != Sqlite.OK
                        || this.insert_event_statement.bind_int (2, (int)event.id) != Sqlite.OK
                        || this.insert_event_statement.bind_double (3, julian_start) != Sqlite.OK
                        || this.insert_event_statement.bind_int (4, (int)event.duration) != Sqlite.OK
                        || this.insert_event_statement.bind_int (5, (int)event.running_status) != Sqlite.OK
                        || this.insert_event_statement.bind_int (6, free_ca_mode) != Sqlite.OK
                        || this.insert_event_statement.bind_text (7, name) != Sqlite.OK
                        || this.insert_event_statement.bind_text (8, desc) != Sqlite.OK
                        || this.insert_event_statement.bind_text (9, ext_desc) != Sqlite.OK) {
                    this.print_last_error ();
                    return false;
                }
                
                if (this.insert_event_statement.step () != Sqlite.DONE) {
                    this.print_last_error ();
                    return false;
                }
            }
            return true;
        }
        
        public Event? get_event (uint event_id, uint channel_sid) {
            this.select_event_statement.reset ();
            
            if (this.select_event_statement.bind_int (1, (int)channel_sid) != Sqlite.OK
                    || this.select_event_statement.bind_int (2, (int)event_id) != Sqlite.OK) {
                this.print_last_error ();
                return null;
            }
            
            int rc = this.select_event_statement.step ();
            
            if (rc != Sqlite.ROW && rc != Sqlite.DONE) {
                this.print_last_error ();
                return null;
            }
            
            // ROW means there's data, DONE means there's none
            if (rc == Sqlite.DONE) return null;
            else return this.create_event_from_statement (this.select_event_statement);
        }
        
        public bool remove_event (uint event_id, Channel channel) {
            if (this.db == null) {
                critical ("SQLite error: No database connection");
                return false;
            }
            
            this.delete_event_statement.reset ();
            
            if (this.delete_event_statement.bind_int (1, (int)channel.Sid) != Sqlite.OK
                    || this.delete_event_statement.bind_int (2, (int)event_id) != Sqlite.OK) {
                this.print_last_error ();
                return false;
            }
            
            if (this.delete_event_statement.step () != Sqlite.DONE) {
                this.print_last_error ();
                return false;
            }
            
            return true;
        }
        
        public bool contains_event (Event event, Channel channel) {
            this.has_event_statement.reset ();
            
            if (this.has_event_statement.bind_int (1, (int)channel.Sid) != Sqlite.OK
                    || this.has_event_statement.bind_int (2, (int)event.id) != Sqlite.OK) {
                this.print_last_error ();
                return false;
            }
            
            int c = 0;
            while (this.has_event_statement.step () == Sqlite.ROW) {
                c = this.has_event_statement.column_int (0);
            }
            
            return (c > 0);
        }
        
        public Gee.List<Event> get_events (Channel channel) {
            Gee.List<Event> events = new ArrayList<Event> ();
            
            if (this.db == null) return events;
            
            string statement_str = SELECT_ALL_EVENTS_STATEMENT.printf (
                channel.Sid);
            
            Statement statement;
            if (this.db.prepare (statement_str, -1, out statement) != Sqlite.OK) {
                this.print_last_error ();
                return events;
            }
            
            while (statement.step () == Sqlite.ROW) {
                Event event = this.create_event_from_statement (statement);
                events.add (event);
            }
            
            return events;
        }
        
        private Event create_event_from_statement (Statement statement) {
            var event = new Event ();
            event.id = (uint)statement.column_int (0);
            
            weak string starttime = statement.column_text (1);
            starttime.scanf ("%04u-%02u-%02u %02u:%02u:%02u",
                &event.year,
                &event.month,
                &event.day,
                &event.hour,
                &event.minute,
                &event.second);
            
            event.duration = (uint)statement.column_int (2);
            event.running_status = (uint)statement.column_int (3);
            event.free_ca_mode = (statement.column_int (4) == 1);
            // Duplicate strings
            event.name = "%s".printf (statement.column_text (5));
            event.description = "%s".printf (statement.column_text (6));
            event.extended_description = "%s".printf (statement.column_text (7));
            // We don't save those
            event.audio_components = null;
            event.video_components = null;
            event.teletext_components = null;
            
            return event;
        }
        
        private void print_last_error () {
            critical ("SQLite error: %d, %s",
                this.db.errcode (), this.db.errmsg ());
        }
        
        private double to_julian (uint year, uint month, uint day,
                uint hour, uint minute, uint second) {
            
            this.to_julian_statement.reset ();
            string datetime_str = "%04u-%02u-%02u %02u:%02u:%02u".printf (
                year, month, day, hour, minute, second);
            
            if (this.to_julian_statement.bind_text (1, #datetime_str)
                    != Sqlite.OK) {
                this.print_last_error ();
                return 0;       
            }
            
            if (this.to_julian_statement.step () != Sqlite.ROW) {
                this.print_last_error ();
                return 0;
            }
            
            return this.to_julian_statement.column_double (0);
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
        
        private static Database? get_db_handler () {
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
                    null, out errormsg);
            
                if (val != Sqlite.OK) {
                    critical ("SQLite error: %s", errormsg);
                    return null;
                }
            }
            
            return db;
        }
    
    }

}
