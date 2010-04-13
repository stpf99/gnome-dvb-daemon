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
import glib
import gettext
import locale
from gettext import gettext as _
from gnomedvb.ui.wizard.pages.BasePage import BasePage
from gnomedvb.ui.widgets.Frame import TextFieldLabel

DVB_APPS_DIRS = ("/usr/share/dvb",
                 "/usr/share/dvb-apps",
                 "/usr/share/dvb-apps/scan",
                 "/usr/share/doc/dvb-utils/examples/scan")
                 
COUNTRIES = {
    "at": "Austria",
    "au": "Australia",
    "be": "Belgium",
    "ch": "Switzerland",
    "cz": "Czech Republic",
    "de": "Germany",
    "dk": "Denmark",
    "es": "Spain",
    "fi": "Finland",
    "fr": "France",
    "gr": "Greece",
    "hk": "Hong Kong",
    "hr": "Hungary",
    "is": "Iceland",
    "it": "Italy",
    "lu": "Luxemburg",
    "nl": "Netherlands",
    "no": "Norway",
    "nz": "New Zealand",
    "pl": "Poland",
    "se": "Sweden",
    "sk": "Slovakia",
    "tw": "Taiwan",
    "uk": "United Kingdom",
}

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
        self.__data_dir = None
        
    def get_page_title(self):
        return self.__page_title
        
    def set_adapter_info(self, info):
        self.__adapter_info = info
        # skip label
        for widget in self.get_children()[1:]:
            widget.destroy()

        if not self.is_dvb_apps_installed():
            self.__page_title = _("Missing requirements")
            self.setup_dvb_apps_missing()
            return
            
        if info["type"] == "DVB-T":
            self.setup_dvb_t()
            self.__page_title = _("Country and antenna selection")
        elif info["type"] == "DVB-S":
            self.setup_dvb_s()
            self.__page_title = _("Satellite selection")
        elif info["type"] == "DVB-C":
            self.setup_dvb_c()
            self.__page_title = _("Country and provider selection")
        else:
            self.__page_title = _("Unsupported adapter")
            self.setup_unknown(info["type"])
            
    def get_tuning_data(self):
        if self.__tuning_data == self.NOT_LISTED:
            self.add_brute_force_scan()
        return self.__tuning_data
        
    def _create_table(self):
        self.table = gtk.Table(rows=4, columns=2)
        self.table.set_row_spacings(6)
        self.table.set_col_spacings(18)
        self.table.show()
        self.pack_start(self.table)

    def is_dvb_apps_installed(self):
        val = False
        for d in DVB_APPS_DIRS:
            if os.path.exists(d):
                val = True
                break
        return val
    
    def setup_unknown(self, devtype):
        # translators: first %s is the DVB type, e.g. DVB-S
        text = _("Sorry, but '%s' cards aren't supported.") % devtype
        self._label.set_markup(text)

    def setup_dvb_apps_missing(self):
        text = "<big><b>%s</b></big>\n%s" % (_("Could not find initial tuning data."),
            _("Please make sure that the dvb-apps package is installed."))
        self._label.set_markup(text)
        
    def setup_dvb_t(self):
        text = "%s %s %s" %(_('Please choose a country and the antenna that is closest to your location.'),
            _("If you don't know which antenna to choose select \"Don't know\" from the list of providers."),
            _("However, searching for channels will take considerably longer this way."))
        self._label.set_markup(text)
    
        self.providers_view = None
        
        countries = {self.NOT_LISTED: _("Not listed")}
        country_codes = ("at", "au", "be", "ch", "cz", "de", "dk", "es", "fi", "fr",
            "gr", "hr", "hk", "is", "it", "lu", "nl", "nz", "pl", "se", "sk",
            "tw", "uk",)
        t = gettext.translation("iso_3166", fallback=True)
        for lang in country_codes:
            countries[lang] = t.ugettext(COUNTRIES[lang])
        
        self._create_table()
        
        country = TextFieldLabel()
        label = country.get_label()
        label.set_markup_with_mnemonic(_("_Country:"))
        country.show()
        self.table.attach(country, 0, 1, 0, 1, yoptions=0, xoptions=gtk.FILL)

        # name, code    
        self.countries = gtk.ListStore(str, str)
        self.countries.set_sort_column_id(0, gtk.SORT_ASCENDING)
        self.countries.set_sort_func(0, self.combobox_sort_func)
        
        for code, name in countries.items():
            self.countries.append([name, code])
    
        self.country_combo = gtk.ComboBox(self.countries)
        self.country_combo.connect('changed', self.on_country_changed)
        self.__data_dir = "dvb-t"
        cell = gtk.CellRendererText()
        self.country_combo.pack_start(cell)
        self.country_combo.add_attribute(cell, "text", 0)
        self.country_combo.show()
        self.table.attach(self.country_combo, 1, 2, 0, 1, yoptions=0)
        self.country_combo.set_active(0)
        label.set_mnemonic_widget(self.country_combo)
        
        providers = TextFieldLabel()
        label = providers.get_label()
        label.set_markup_with_mnemonic(_("_Antenna:"))
        providers.show()
        self.table.attach(providers, 0, 1, 1, 2, yoptions=0, xoptions=gtk.FILL)
        
        self.providers = gtk.ListStore(str, str)
        self.providers.set_sort_column_id(0, gtk.SORT_ASCENDING)
        self.providers.set_sort_func(0, self.combobox_sort_func)
        
        self.providers_view, scrolledview = self._create_providers_treeview(
            self.providers, _("Antenna"))
        self.providers_view.get_selection().connect('changed',
            self.on_providers_changed)
        label.set_mnemonic_widget(self.providers_view)
        
        self.table.attach(scrolledview, 0, 2, 2, 3)
        
        self.providers_view.set_sensitive(False)
   
    def setup_dvb_s(self):
        
        satellite = TextFieldLabel()
        label = satellite.get_label()
        label.set_markup_with_mnemonic(_("_Satellite:"))
        satellite.show()
        self.pack_start(satellite, False, False, 0)
        
        self.satellites = gtk.ListStore(str, str)
        self.satellites.set_sort_column_id(0, gtk.SORT_ASCENDING)
        
        self.satellite_view, scrolledview = self._create_providers_treeview(
            self.satellites, _("Satellite"))
        self.satellite_view.get_selection().connect("changed",
            self.on_satellite_changed)
        label.set_mnemonic_widget(self.satellite_view)
        self.pack_start(scrolledview)
        
        self.read_satellites()
        
    def setup_dvb_c(self):
        countries = {}
        country_codes = ("at", "be", "ch", "de", "fi", "lu", "nl", "se", "no",)
        t = gettext.translation("iso_3166", fallback=True)
        for lang in country_codes:
            countries[lang] = t.ugettext(COUNTRIES[lang])
            
        self._create_table()
            
        country = TextFieldLabel()
        label = country.get_label()
        label.set_markup_with_mnemonic(_("_Country:"))
        country.show()
        self.table.attach(country, 0, 1, 0, 1, yoptions=0, xoptions=gtk.FILL)
    
        self.countries = gtk.ListStore(str, str)
        self.countries.set_sort_column_id(0, gtk.SORT_ASCENDING)
        self.countries.set_sort_func(0, self.combobox_sort_func)
        
        for code, name in countries.items():
            self.countries.append([name, code])
    
        self.country_combo = gtk.ComboBox(self.countries)
        self.country_combo.connect('changed', self.on_country_changed)
        self.__data_dir = "dvb-c"
        cell = gtk.CellRendererText()
        self.country_combo.pack_start(cell)
        self.country_combo.add_attribute(cell, "text", 0)
        self.country_combo.show()
        self.table.attach(self.country_combo, 1, 2, 0, 1, yoptions=0)
        label.set_mnemonic_widget(self.country_combo)
        
        providers = TextFieldLabel()
        label = providers.get_label()
        label.set_markup_with_mnemonic(_("_Providers:"))
        providers.show()
        self.table.attach(providers, 0, 1, 1, 2, yoptions=0, xoptions=gtk.FILL)
        
        self.providers = gtk.ListStore(str, str)
        self.providers.set_sort_column_id(0, gtk.SORT_ASCENDING)
        
        self.providers_view, scrolledview = self._create_providers_treeview(
            self.providers, _("Provider"))
        self.providers_view.get_selection().connect('changed',
            self.on_providers_changed)
        label.set_mnemonic_widget(self.providers_view)
        
        self.table.attach(scrolledview, 0, 2, 2, 3)
        self.providers_view.set_sensitive(False)
         
    def _create_providers_treeview(self, providers, col_name):
        providers_view = gtk.TreeView(providers)
        providers_view.set_headers_visible(False)
        col = gtk.TreeViewColumn(col_name)
        cell = gtk.CellRendererText()
        col.pack_start(cell)
        col.add_attribute(cell, "markup", 0)
        providers_view.append_column(col)
        providers_view.show()
        
        scrolledview= gtk.ScrolledWindow()
        scrolledview.add(providers_view)
        scrolledview.set_policy(gtk.POLICY_NEVER, gtk.POLICY_AUTOMATIC)
        scrolledview.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        scrolledview.show()
        
        return providers_view, scrolledview
        
    def on_country_changed(self, combo):
        aiter = combo.get_active_iter()
        
        if aiter != None:
            selected_country = self.countries[aiter][1]
    
            if selected_country == self.NOT_LISTED:
                if self.providers_view:
                    self.providers_view.set_sensitive(False)
                self.emit("finished", True)
            else:
                self.emit("finished", False)
                self.providers.clear()

                toplevel_window = self.get_toplevel().window
                toplevel_window.set_cursor(gtk.gdk.Cursor(gtk.gdk.WATCH))
                
                # Fill list async
                glib.idle_add(self._fill_providers, selected_country)            

    def _fill_providers(self, selected_country):
        # Only DVB-T has bruteforce scan
        if self.__adapter_info["type"] == "DVB-T":
            self.providers.append([_("Don't know"), self.NOT_LISTED])

        for d in DVB_APPS_DIRS:
            if os.access(d, os.F_OK | os.R_OK):
                for f in os.listdir(os.path.join(d, self.__data_dir)):
                    values = f.split('-', 1)
                    if len(values) != 2:
                        continue
                    country, city = values
                
                    if country == selected_country:
                        self.providers.append([city,
                            os.path.join(d, self.__data_dir, f)])
    
        self.providers_view.set_sensitive(True)
        first_iter = self.providers.get_iter_first()
        self.providers_view.get_selection().select_iter(first_iter)

        self.get_toplevel().window.set_cursor(None)
        self.emit("finished", True)

        return False
        
    def on_providers_changed(self, selection):
        model, aiter = selection.get_selected()
        
        if aiter != None:
            self.__tuning_data = self.providers[aiter][1]
            self.emit("finished", True)
    
    def read_satellites(self):
        for d in DVB_APPS_DIRS:
            if os.access(d, os.F_OK | os.R_OK):
                for f in os.listdir(os.path.join(d, 'dvb-s')):
                    self.satellites.append([f, os.path.join(d, 'dvb-s', f)])
                        
    def on_satellite_changed(self, selection):
        model, aiter = selection.get_selected()
        
        if aiter != None:
            self.__tuning_data = self.satellites[aiter][1]
            self.emit("finished", True)
    
    def on_scan_all_toggled(self, checkbutton):
        state = not checkbutton.get_active()
        self.country_combo.set_sensitive(state)
        self.providers_view.set_sensitive(state)
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
            return locale.strcoll(name1, name2)
    
