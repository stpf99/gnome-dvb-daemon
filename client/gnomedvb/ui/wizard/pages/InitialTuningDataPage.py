# -*- coding: utf-8 -*-
# Copyright (C) 2008,2009 Sebastian Pölsterl
#
# This file is part of GNOME DVB Daemon.
#
# GNOME DVB Daemon is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNOME DVB Daemon is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.

import os
import os.path
import gtk
import gobject
from gettext import gettext as _
from gnomedvb.ui.wizard.pages.BasePage import BasePage

DVB_APPS_DIRS = ("/usr/share/dvb",
                 "/usr/share/dvb-apps",
                 "/usr/share/doc/dvb-utils/examples/scan")

class InitialTuningDataPage(BasePage):
    
    __gsignals__ = {
            "finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [bool]),
    }
    NOT_LISTED = "00"

    def __init__(self):
        BasePage.__init__(self)
        
        self.__adapter_info = None
        self.__page_title = None
        self.__tuning_data = self.NOT_LISTED
        
    def get_page_title(self):
        return self.__page_title
        
    def set_adapter_info(self, info):
        self.__adapter_info = info
        
        for widget in self.get_children():
            widget.destroy()
            
        if info["type"] == "DVB-T":
            self.setup_dvb_t()
            self.__page_title = _("Country and antenna selection")
        elif info["type"] == "DVB-S":
            self.setup_dvb_s()
            self.__page_title = _("Country and antenna selection")
        elif info["type"] == "DVB-C":
            self.setup_dvb_c()
            self.__page_title = _("Country and provider selection")
        else:
            self.setup_unknown(info["type"])
            
    def get_tuning_data(self):
        if self.__tuning_data == self.NOT_LISTED:
            self.add_brute_force_scan()
        return self.__tuning_data
        
    def _create_table(self):
        self.table = gtk.Table(rows=5, columns=2)
        self.table.set_row_spacings(6)
        self.table.set_col_spacings(3)
        self.table.show()
        self.pack_start(self.table)
    
    def setup_unknown(self, devtype):
        label = gtk.Label()
        label.set_line_wrap(True)
        # translators: first %s is the DVB type, e.g. DVB-S
        text = _("Sorry, but '%s' cards aren't supported.") % devtype
        label.set_markup(text)
        label.show()
        self.pack_start(label)
        
    def setup_dvb_t(self):
        label = gtk.Label()
        label.set_line_wrap(True)
        text = "%s %s %s" %(_('Please choose a country and the antenna that is closest to your location.'),
            _("If you don't know which antenna to choose select \"Don't know\" from the list of providers."),
            _("However, searching for channels will take considerably longer this way."))
        label.set_markup(text)
        label.show()
        self.pack_start(label)
    
        self.providers_combo = None
        
        countries = {self.NOT_LISTED: _("Not listed"),
             "at": _("Austria"), "au": _("Australia"), "be": _("Belgium"),
             "ch": _("Switzerland"), "cz": _("Czech Republic"), "de": _("Germany"),
             "dk": _("Denmark"), "es": _("Spain"), "fi": _("Finland"), "fr": _("France"),
             "gr": _("Greece"), "hr": _("Hungary"), "is": _("Iceland"), "it": _("Italy"),
             "lu": _("Luxemburg"), "nl": _("Netherlands"), "nz": _("New Zealand"),
             "pl": _("Poland"), "se": _("Sweden"), "sk": _("Slovakia"), "tw": _("Taiwan"),
             "uk": _("United Kingdom"), "hk": _("Hong Kong") }
    
        self._create_table()
        
        country = gtk.Label()
        country.set_markup(_("<b>Country:</b>"))
        country.show()
        self.table.attach(country, 0, 1, 0, 1, yoptions=0)

        # name, code    
        self.countries = gtk.ListStore(str, str)
        self.countries.set_sort_column_id(0, gtk.SORT_ASCENDING)
        self.countries.set_sort_func(0, self.combobox_sort_func)
        
        for code, name in countries.items():
            self.countries.append([name, code])
    
        self.country_combo = gtk.ComboBox(self.countries)
        self.country_combo.connect('changed', self.on_country_changed, "dvb-t")
        cell = gtk.CellRendererText()
        self.country_combo.pack_start(cell)
        self.country_combo.add_attribute(cell, "text", 0)
        self.country_combo.show()
        self.table.attach(self.country_combo, 1, 2, 0, 1, yoptions=0)
        self.country_combo.set_active(0)
        
        self.providers_label = gtk.Label()
        self.providers_label.set_markup(_("<b>Antenna:</b>"))
        self.providers_label.show()
        self.table.attach(self.providers_label, 0, 1, 1, 2, yoptions=0)
        
        self.providers = gtk.ListStore(str, str)
        self.providers.set_sort_column_id(0, gtk.SORT_ASCENDING)
        self.providers.set_sort_func(0, self.combobox_sort_func)
        
        self.providers_combo = gtk.ComboBox(self.providers)
        self.providers_combo.connect('changed', self.on_providers_changed)
        cell = gtk.CellRendererText()
        self.providers_combo.pack_start(cell)
        self.providers_combo.add_attribute(cell, "text", 0)
        self.providers_combo.show()
        self.table.attach(self.providers_combo, 1, 2, 1, 2, yoptions=0)
        self.providers_combo.set_sensitive(False)
        
    def setup_dvb_s(self):
        hbox = gtk.HBox(spacing=6)
        hbox.show()
        self.pack_start(hbox, False)
        
        satellite = gtk.Label()
        satellite.set_markup(_("<b>Satellite:</b>"))
        satellite.show()
        hbox.pack_start(satellite, False, False, 0)
        
        self.satellites = gtk.ListStore(str, str)
        self.satellites.set_sort_column_id(0, gtk.SORT_ASCENDING)
        
        self.satellite_combo = gtk.ComboBox(self.satellites)
        self.satellite_combo.connect("changed", self.on_satellite_changed)
        cell = gtk.CellRendererText()
        self.satellite_combo.pack_start(cell)
        self.satellite_combo.add_attribute(cell, "text", 0)
        self.satellite_combo.show()
        hbox.pack_start(self.satellite_combo, False, False, 0)
        
        self.read_satellites()
        
    def setup_dvb_c(self):
        countries = {"at": _("Austria"), "be": _("Belgium"),
             "ch": _("Switzerland"), "de": _("Germany"), "fi": _("Finland"),
             "lu": _("Luxemburg"), "nl": _("Netherlands"), "se": _("Sweden"),
             "no": _("Norway")
             }
            
        self._create_table()
            
        country = gtk.Label()
        country.set_markup(_("<b>Country:</b>"))
        country.show()
        self.table.attach(country, 0, 1, 0, 1, yoptions=0)
    
        self.countries = gtk.ListStore(str, str)
        self.countries.set_sort_column_id(0, gtk.SORT_ASCENDING)
        
        for code, name in countries.items():
            self.countries.append([name, code])
    
        self.country_combo = gtk.ComboBox(self.countries)
        self.country_combo.connect('changed', self.on_country_changed, "dvb-c")
        cell = gtk.CellRendererText()
        self.country_combo.pack_start(cell)
        self.country_combo.add_attribute(cell, "text", 0)
        self.country_combo.show()
        self.table.attach(self.country_combo, 1, 2, 0, 1, yoptions=0)
        
        self.providers_label = gtk.Label()
        self.providers_label.set_markup(_("<b>Providers:</b>"))
        self.providers_label.show()
        self.table.attach(self.providers_label, 0, 1, 1, 2, yoptions=0)
        
        self.providers = gtk.ListStore(str, str)
        self.providers.set_sort_column_id(0, gtk.SORT_ASCENDING)
        
        self.providers_combo = gtk.ComboBox(self.providers)
        self.providers_combo.connect('changed', self.on_providers_changed)
        cell = gtk.CellRendererText()
        self.providers_combo.pack_start(cell)
        self.providers_combo.add_attribute(cell, "text", 0)
        self.providers_combo.show()
        self.table.attach(self.providers_combo, 1, 2, 1, 2, yoptions=0)
        self.providers_combo.set_sensitive(False)
    
    def on_country_changed(self, combo, directory):
        aiter = combo.get_active_iter()
        
        if aiter != None:
            selected_country = self.countries[aiter][1]
    
            if selected_country == self.NOT_LISTED:
                if self.providers_combo:
                    self.providers_combo.set_sensitive(False)
            else:
                self.providers.clear()
                self.providers.append([_("Don't know"), self.NOT_LISTED])
                for d in DVB_APPS_DIRS:
                    if os.access(d, os.F_OK | os.R_OK):
                        for f in os.listdir(os.path.join(d, directory)):
                            country, city = f.split('-', 1)
                        
                            if country == selected_country:
                                self.providers.append([city, os.path.join(d, directory, f)])
            
                self.providers_combo.set_sensitive(True)
                self.providers_combo.set_active(0)
            self.emit("finished", True)
        
    def on_providers_changed(self, combo):
        aiter = combo.get_active_iter()
        
        if aiter != None:
            self.__tuning_data = self.providers[aiter][1]
            self.emit("finished", True)
    
    def read_satellites(self):
        for d in DVB_APPS_DIRS:
            if os.access(d, os.F_OK | os.R_OK):
                for f in os.listdir(os.path.join(d, 'dvb-s')):
                    self.satellites.append([f, os.path.join(d, 'dvb-s', f)])
                        
    def on_satellite_changed(self, combo):
        aiter = combo.get_active_iter()
        
        if aiter != None:
            self.__tuning_data = self.satellites[aiter][1]
            self.emit("finished", True)
    
    def on_scan_all_toggled(self, checkbutton):
        state = not checkbutton.get_active()
        self.country_combo.set_sensitive(state)
        self.providers_combo.set_sensitive(state)
        self.add_brute_force_scan()
        self.emit("finished", not state)
    
    def add_brute_force_scan(self):
        self.__tuning_data = []
        for chan in range(5, 13):
            freq = 142500000 + chan * 7000000
            for transmode in ["2k", "8k"]:
                for guard in [0, 32, 16, 8, 4]:
                    self.__tuning_data.append(
                        [freq,
                         4, # hierarchy: AUTO
                         7, # bandwidth
                         transmode,
                         "NONE", # code-rate-hp
                         "AUTO", # code-rate-lp
                         "QAM64", # constellation
                         guard, # guard interval
                        ])

        for chan in range(21, 70):
            freq = 306000000 + chan* 8000000
            for transmode in ["2k", "8k"]:
                for guard in [32, 16, 8, 4]:
                    self.__tuning_data.append(
                        [freq,
                         4, # hierarchy: AUTO
                         8, # bandwidth
                         transmode,
                         "NONE", # code-rate-hp
                         "AUTO", # code-rate-lp
                         "QAM64", # constellation
                         guard, # guard interval
                        ])

    def combobox_sort_func(self, model, iter1, iter2):
        name1, code1 = model[iter1]
        name2, code2 = model[iter2]

        if code1 == self.NOT_LISTED:
            return -1
        elif code2 == self.NOT_LISTED:
            return 1
        else:
            return cmp(name1, name2)
    
