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

namespace DVB.RTSPServer {

    private static Gst.RTSPServer server;

    public static void start () {
        server = new Gst.RTSPServer ();
        server.set_media_mapping (new MediaMapping ());
        server.attach (null);
        GLib.Timeout.add_seconds (2, (GLib.SourceFunc)timeout);
    }
    
    public static void shutdown () {
        server = null;
    }
    
    public static void stop_streaming (Channel channel) {
        Gst.RTSPUrl url;
        Gst.RTSPUrl.parse (channel.URL, out url);
        debug ("Stop streaming channel with URL %s", url.abspath);
        List<Gst.RTSPSession> sessions = server.session_pool.find_by_uri (url);

        for (int i=0; i<sessions.length(); i++) {
            Gst.RTSPSession sess = sessions.nth_data (i);
            server.session_pool.remove (sess);
        }
    }
    
    private static bool timeout () {
        Gst.RTSPSessionPool pool = server.get_session_pool ();
        pool.cleanup ();
        return true;
    }

}
