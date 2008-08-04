#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gtk
from gnomedvb.wizard.SetupWizard import SetupWizard
	
if __name__ == '__main__':
	w = SetupWizard()
	w.show_all()
	gtk.main ()
	
