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

namespace DVB.database.SqliteUtils {

    /**
     * Replace "'" with "''"
     */
    public static string escape (string? text) {
        if (text == null) return "";
    
        Regex regex;
        try {
            regex = new Regex ("'",
                RegexCompileFlags.MULTILINE,
                0);
        } catch (RegexError e) {
            warning ("RegexError: %s", e.message);
            return text;
        }
        
        string escaped_str;
        try {
            escaped_str = regex.replace_literal (text, -1,
                0, "''", 0);
        } catch (RegexError e) {
            warning ("RegexError: %s", e.message);
            return text;
        }
        
        return escaped_str;
    }
    
    /**
     * Replace "''" with "'"
     */
    public static string unescape (string text) {
        Regex regex;
        try {
            regex = new Regex ("''",
                RegexCompileFlags.MULTILINE,
                0);
        } catch (RegexError e) {
            warning ("RegexError: %s", e.message);
            return text;
        }
        
        string new_str;
        try {
            new_str = regex.replace_literal (text, -1,
                0, "'", 0);
        } catch (RegexError e) {
            warning ("RegexError: %s", e.message);
            return text;
        }
        
        return new_str;
    }

}
