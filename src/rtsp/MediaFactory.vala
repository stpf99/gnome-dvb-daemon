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

    public class MediaFactory : Gst.RTSPMediaFactory {

        private Gst.Element? pipeline;

        construct {
            this.set_shared (true);
        }

        public override Gst.Element? get_element (Gst.RTSPUrl url) {
            uint sidnr = 0;
          	uint grpnr = 0;
          	
          	string[] path_elements = url.abspath.split ("/");
          	int i = 0;
          	string elem;
          	while ((elem = path_elements[i]) != null) {
          	    if (i == 1)
          	        grpnr = (uint)elem.to_int ();
          	    else if (i == 2)
          	        sidnr = (uint)elem.to_int ();
          	    
          	    i++;
          	}
          	
          	Manager manager = Manager.get_instance();
          	
          	DeviceGroup? devgrp = 
          	    manager.get_device_group_if_exists (grpnr);
          	if (devgrp == null) {
          	    warning ("Unknown group %u", grpnr);
          	    return null;
          	}
          	
          	Gst.Element payload = Gst.ElementFactory.make ("rtpmp2tpay",
                "pay0");
            if (payload == null) {
                critical ("Could not create rtpmp2tpay element");
                return null;   
            }
          	
          	Channel channel = devgrp.Channels.get_channel (sidnr);
          	ChannelFactory channels_factory = devgrp.channel_factory;
          	
          	PlayerThread? player = channels_factory.watch_channel (channel, payload);
          	if (player == null) {
          	    critical ("Could not find channel");
          	    return null;
          	}
          	Gst.Element? bin = player.get_sink_bin (sidnr);
          	this.pipeline = player.get_pipeline ();
          	
          	return bin;
        }
        
        public override Gst.RTSPMedia? @construct (Gst.RTSPUrl url) {
            Gst.Element? element = this.get_element (url);
            
            if (element == null)
                return null;
            
            Gst.RTSPMedia media = new Gst.RTSPMedia ();
            media.element = element;
            media.pipeline = this.pipeline;
            
            this.collect_streams (url, media);
        
            return media;
        }

        public override string gen_key (Gst.RTSPUrl url) {
            return url.abspath;
        }
        
    }

}
