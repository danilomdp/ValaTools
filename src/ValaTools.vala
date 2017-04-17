/*
 *  Copyright (c) 2017 Danilo <danilomdpd@gmail.com>
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

using Gtk;

public const string NAME = "Vala Tools";
public const string DESCRIPTION = "Tools for Vala development within Scratch";

namespace Scratch.Plugins {
    public class ValaTools : Peas.ExtensionBase, Peas.Activatable, PeasGtk.Configurable {
    
        Scratch.Services.Interface plugins;
        public Object object { owned get; construct; }
        
        /* Plugin Controller */
        private ValaToolsController controller;
        public void activate () {
            plugins = (Scratch.Services.Interface) object;
            
            controller = new ValaToolsController ();
            controller.activate ();
            plugins.hook_document.connect (controller.on_hook_document);
            plugins.hook_window.connect (controller.on_hook_window);

            debug ("----------- Vala Tools for Scratch -------------\n");
        }
         
        public void deactivate () {}
        
        public void update_state () {}

        public Gtk.Widget create_configure_widget () {return new Gtk.Label("Not implemented yet");}
        
    }
}

 [ModuleInit]
 public void peas_register_types (GLib.TypeModule module) {
     var objmodule = module as Peas.ObjectModule;
     objmodule.register_extension_type (typeof (Peas.Activatable), typeof (Scratch.Plugins.ValaTools));
     objmodule.register_extension_type (typeof (PeasGtk.Configurable), typeof (Scratch.Plugins.ValaTools));
 }
