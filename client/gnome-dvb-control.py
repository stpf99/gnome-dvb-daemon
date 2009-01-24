#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gtk
from gnomedvb.ui.controlcenter.ControlCenterWindow import ControlCenterWindow
from gnomedvb.DVBModel import DVBModel
                   
if __name__ == '__main__':
    model = DVBModel()
    w = ControlCenterWindow(model)
    w.show_all()

    gtk.main()
    
        
        
