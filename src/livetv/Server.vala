using GLib;

namespace DVB {

    /**
     * RTSP Server
     *
     * It listens on port 1554.
     * E.g. http://localhost:1554/3/514
     * will open the channel with sid 514 of device group 3
     */
    public class Server : Gst.RTSPServer {
    
        private string sid;
        private Gst.Bin dvbrtpbin;
        
        public override weak Gst.Element? prepare_media (Gst.RTSPMedia media,
                Gst.Bin bin) {
          	uint sidnr = 0;
          	uint grpnr = 0;
          	
          	string[] path_elements = media.url.abspath.split ("/");
          	int i = 0;
          	string elem;
          	while ((elem = path_elements[i]) != null) {
          	    if (i == 1)
          	        grpnr = (uint)elem.to_int ();
          	    else if (i == 2)
          	        sidnr = (uint)elem.to_int ();
          	    
          	    i++;
          	}
          	
          	// TODO stop epg scanner
          	
          	DeviceGroup? devgrp =
          	    Manager.get_instance().get_device_group_if_exists (grpnr);
          	if (devgrp == null) {
          	    warning ("Unknown group %u", grpnr);
          	    return null;
          	}
          	
          	Device? free_dev = devgrp.get_next_free_device ();
          	if (free_dev == null) {
          	    warning ("All devices of group %u are currently busy", grpnr);
          	    return null;
          	}
          	
          	Channel? channel = free_dev.Channels.get (sidnr);
          	if (channel == null) {
          	    warning ("No channel %u in group %u", sidnr, grpnr);
          	    return null;
          	}
          	
          	this.sid = sidnr.to_string ();
          	
          	// TODO redirect epg data to EPGScanner
          	
          	Gst.Element dvbbasebin = Gst.ElementFactory.make ("dvbbasebin",
                    "dvbbasebin");
            dvbbasebin.pad_added += this.on_dvbbasebin_pad_added;
            channel.setup_dvb_source (dvbbasebin);
            
            Gst.Element payload = Gst.ElementFactory.make ("rtpmp2tpay",
                "pay0");
            
            this.dvbrtpbin = new Gst.Bin ("dvbrtpbin");
            this.dvbrtpbin.add (dvbbasebin);
            this.dvbrtpbin.add (payload);
            
            dvbbasebin.set ("program-numbers", this.sid);
            dvbbasebin.set ("adapter", free_dev.Adapter);
            dvbbasebin.set ("frontend", free_dev.Frontend);
          	
          	return dvbrtpbin;
        }
        
        private void on_dvbbasebin_pad_added (Gst.Element elem, Gst.Pad pad) {
            debug ("Pad %s added", pad.get_name());
            
            string program = "program_%s".printf (this.sid);
            if (pad.get_name() == program) {
                string sink_name = "pay0";
                Gst.Element sink = ((Gst.Bin) this.dvbrtpbin).get_by_name (
                    sink_name);
                if (sink == null) {
                    critical ("No element with name %s", sink_name);
                } else {
                    // Link dvbbasebin and rtpmp2tpay
                    Gst.Pad sinkpad = sink.get_pad ("sink");
                    
                    Gst.PadLinkReturn rc = pad.link (sinkpad);
                    if (rc != Gst.PadLinkReturn.OK) {
                        critical ("Could not link pads");
                    }
                    debug ("Src pad %s linked with sink pad %s",
                        program, sink_name);
                }
            }
        }

    }
   
}
