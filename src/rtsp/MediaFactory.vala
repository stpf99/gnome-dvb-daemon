using GLib;

namespace DVB {

    public class MediaFactory : Gst.RTSPMediaFactory {
        
        private string? sid;
        private Gst.Bin dvbrtpbin;
        private EPGScanner? epgscanner;
        
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
          	
          	// Stop EPG scanner
          	this.epgscanner = devgrp.epgscanner;
          	if (epgscanner != null) epgscanner.stop ();
          	
          	Device? free_dev = devgrp.get_next_free_device ();
          	if (free_dev == null) {
          	    warning ("All devices of group %u are currently busy", grpnr);
          	    return null;
          	}
          	
          	Channel? channel = free_dev.Channels.get_channel (sidnr);
          	if (channel == null) {
          	    warning ("No channel %u in group %u", sidnr, grpnr);
          	    return null;
          	}
          	
          	this.sid = sidnr.to_string ();
          	/*
          	FIXME: We need a way to get to the pipeline
            Gst.Bus bus = pipeline.get_bus();
            bus.add_signal_watch();
            bus.message += this.bus_watch_func;
          	*/
          	Gst.Element dvbbasebin = Gst.ElementFactory.make ("dvbbasebin",
                    "dvbbasebin");
            if (dvbbasebin == null) {
                critical ("Could not create dvbbasebin element");
                return null;
            }
            dvbbasebin.pad_added += this.on_dvbbasebin_pad_added;
            channel.setup_dvb_source (dvbbasebin);
            
            Gst.Element payload = Gst.ElementFactory.make ("rtpmp2tpay",
                "pay0");
            if (payload == null) {
                critical ("Could not create rtpmp2tpay element");
                return null;   
            }
            
            this.dvbrtpbin = new Gst.Bin ("dvbrtpbin");
            this.dvbrtpbin.add (dvbbasebin);
            this.dvbrtpbin.add (payload);
            
            dvbbasebin.set ("program-numbers", this.sid);
            dvbbasebin.set ("adapter", free_dev.Adapter);
            dvbbasebin.set ("frontend", free_dev.Frontend);
          	
          	return this.dvbrtpbin;
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
                
                this.sid = null;
            }
        }
        
        private void bus_watch_func (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
                case Gst.MessageType.ELEMENT:
                    string structure_name = message.structure.get_name();
                    if (structure_name == "eit") {
			if (this.epgscanner != null)
                            this.epgscanner.on_eit_structure (message.structure);
                    }
                    break;
                case Gst.MessageType.STATE_CHANGED:
                    int enumval;
                    message.structure.get_enum ("new-state", typeof(Gst.State),
                        out enumval);
                    if (enumval == Gst.State.NULL) {
                        debug ("Pipeline stopped");
                        this.sid = null;
                        // Start EPG scanner again
                        if (this.epgscanner != null)
                            this.epgscanner.start ();
                        this.epgscanner = null;
                    }
                    break;
            }
        }
        
    }

}
