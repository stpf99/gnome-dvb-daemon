/*
 * Copyright (C) 2008-2010 Sebastian Pölsterl
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
    private static uint timeout_id;

    public static bool start () {
        message ("Starting RTSP server");
        server = new Gst.RTSPServer ();
        server.set_media_mapping (new MediaMapping ());
        server.set_address (Environment.get_host_name());
        server.attach (null);
        timeout_id = GLib.Timeout.add_seconds (2, (GLib.SourceFunc)timeout);
        return false;
    }
    
    public static void shutdown () {
        GLib.Source.remove (timeout_id);
        server = null;
    }
    
    public static void stop_streaming (Channel channel) {
        debug ("Stop streaming channel %s", channel.Name);
        
        var helper = new StopChannelHelper (channel.URL);
        server.session_pool.filter (helper.session_filter_func);
    }
    
    private static bool timeout () {
        Gst.RTSPSessionPool pool = server.get_session_pool ();
        pool.cleanup ();
        return true;
    }

    private class StopChannelHelper {
        private Gst.RTSPUrl url;
        
        public StopChannelHelper (string url_str) {
            Gst.RTSPUrl.parse (url_str, out this.url);
        }
        
        public Gst.RTSPFilterResult session_filter_func (Gst.RTSPSessionPool pool,
                Gst.RTSPSession session) {
            if (session.get_media (this.url) != null) {
                return Gst.RTSPFilterResult.REMOVE;
            } else {
                return Gst.RTSPFilterResult.KEEP;
            }    
        }
    }
    
}
