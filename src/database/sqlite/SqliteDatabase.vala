/*
 * Copyright (C) 2009 Sebastian Pölsterl
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
using Sqlite;

namespace DVB.database.sqlite {

    public abstract class SqliteDatabase : GLib.Object {

        public File database_file {get; construct;}
        
        protected Database db;
        private int new_version;

        public SqliteDatabase (File dbfile, int version) {
            this.database_file = dbfile;
            this.new_version = version;
        }

        /**
         * Open database and create or upgrade tables if neccessary
         */
        public void open () throws SqlError {
            if (this.db != null) return;

            File dbfile = this.database_file;
            bool create_tables = (!dbfile.query_exists (null));

            if (Database.open (dbfile.get_path (), out this.db) != Sqlite.OK) {
                this.throw_last_error ();
            }

            int version = this.get_version ();
            
            if (create_tables) {
                debug ("Creating tables");
                this.create ();
            } else if (this.new_version > version) {
                debug ("Updating tables");
                this.upgrade (version, this.new_version);
            }
            this.set_version (this.new_version);

            this.on_open ();
        }

        /**
         * Set database version
         */
        public void set_version (int version) {
            try {
                this.exec_sql ("PRAGMA user_version = %d".printf (version));
            } catch (SqlError e) {
                critical ("%s", e.message);
            }
        }

        /**
         * Get database version
         */
        public int get_version () {
            int version = 0;
            try {
                version = this.simple_query_int ("PRAGMA user_version");
            } catch (SqlError e) {
                critical ("%s", e.message);
            }
            return version;
        }

        public int simple_query_int (string sql) throws SqlError {
            Statement st;
            this.db.prepare (sql, -1, out st);
            int ret = 0;
            if (st.step () == Sqlite.ROW) {
                ret = st.column_int (0);
            } else {
                this.throw_last_error ();
            }
            return ret;
        }

        public void exec_sql (string sql) throws SqlError {
            string errmsg;
            int val = this.db.exec (sql, null, out errmsg);
            if (val != Sqlite.OK) this.throw_last_error ();
        }

        protected void throw_last_error (string? errmsg=null) throws SqlError {
            int code = this.db.errcode ();
            string msg;
            if (errmsg == null) {
                msg = "SqlError: %d: %s".printf (code, this.db.errmsg ());
            } else {
                msg = errmsg;
            }
            
            switch (code) {
                case 1: throw new SqlError.ERROR (msg);
                case 2: throw new SqlError.INTERNAL (msg);
                case 3: throw new SqlError.PERM (msg);
                case 4: throw new SqlError.ABORT (msg);
                case 5: throw new SqlError.BUSY (msg);
                case 6: throw new SqlError.LOCKED (msg);
                case 7: throw new SqlError.NOMEN (msg);
                case 8: throw new SqlError.READONLY (msg);
                case 9: throw new SqlError.INTERRUPT (msg);
                case 10: throw new SqlError.IOERR (msg);
                case 11: throw new SqlError.CORRUPT (msg);
                case 12: throw new SqlError.NOTFOUND (msg);
                case 13: throw new SqlError.FULL (msg);
                case 14: throw new SqlError.CANTOPEN (msg);
                case 15: throw new SqlError.PROTOCOL (msg);
                case 16: throw new SqlError.EMPTY (msg);
                case 17: throw new SqlError.SCHEMA (msg);
                case 18: throw new SqlError.TOOBIG    (msg);
                case 19: throw new SqlError.CONSTRAINT (msg);
                case 20: throw new SqlError.MISMATCH (msg);
                case 21: throw new SqlError.MISUSE (msg);
                case 22: throw new SqlError.NOLFS (msg);
                case 23: throw new SqlError.AUTH (msg);
                case 24: throw new SqlError.FORMAT (msg);
                case 25: throw new SqlError.RANGE (msg);
                case 26: throw new SqlError.NOTADB (msg);
                default: break;
            }
        }

        /**
         * Called when the database is created for the first time.
         * Put the commands required to create all tables here.
         */
        public abstract void create () throws SqlError;

        /**
         * Called when the database needs to be upgraded.
         */
        public abstract void upgrade (int old_version, int new_version) throws SqlError;

        /**
          * Called when the database has been opened.
          */
        public abstract void on_open ();

    }

}
