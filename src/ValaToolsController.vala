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

public class Scratch.Plugins.ValaToolsController : GLib.Object {

    private const string OPENED_FOLDERS_SCHEMA = "org.pantheon.scratch.plugins.folder-manager";

    public string project_path = "";
    // TODO: These paths should be configurable by the user at preferences widget
    public string[] vapi_folders = {"/usr/share/vala-0.34/vapi/", "/usr/share/vala/vapi/", "/usr/local/share/vala-0.34/vapi/"};
    public CMakeValaReader project_file_reader;

    public Scratch.MainWindow window; 
    public Scratch.Services.Document? current_document {get; private set;}
    public ValaCompletionProvider? completion_provider {get; private set;}
    
    public ValaToolsController () {
        completion_provider = null;
    }
    
    public void activate () {
        debug ("[ValaTools] Activated \n");
        try {
            var folder_settings = new GLib.Settings(OPENED_FOLDERS_SCHEMA);
            if(folder_settings==null) {
                debug ("[Vala Tools] No project folder found! Open one to use ValaTools\n");
                return;    
            }

            debug ("[ValaTools] Loading opened folders\n");
            var paths = folder_settings.get_strv ("opened-folders");
            project_path = paths[paths.length-1];
            debug ("[ValaTools] project_path = " + project_path + "\n");

            project_file_reader = new CMakeValaReader ();
        } catch (Error e) {
            debug ("[ValaTools] No project found! open a folder with the 'folder-manager' plugin to use ValaTools\n");
        }
    }
    
    public void deactivate () {
        completion_provider = null;
    }

    public void on_hook_window (Scratch.MainWindow window) {
        this.window = window;
    }
    
    public void on_hook_document (Scratch.Services.Document doc) {
        debug ( "[ValaTools] Document with " + doc.get_language_name () + "\n" );

        if(this.current_document != doc){
            this.current_document = doc;
        }

        var  current_editor = this.current_document.source_view;

        if (completion_provider==null) {
            completion_provider = new ValaCompletionProvider (this);
            completion_provider.engine.end_parsing.connect (on_end_parsing);
            window.toolbar.subtitle = "Analyzing project files";


            string directory = project_path;
            File test_file;

            // Analyze CMakeLists file at current directory
            var read = project_file_reader.parse_file (directory + "/CMakeLists.txt");
            if (!read) {
                warning ("[ValaTools] Can't open CMakeLists.txt at the project folder root.\n");
                doc.set_message (Gtk.MessageType.WARNING, "Can't open CMakeLists.txt in the project folder root", "Close", ()=>{doc.hide_info_bar(); window.toolbar.subtitle = "";});
            }

            //
            // Add vapi files from 'CMakeLists.txt' packages
            // Path is formed using the provided vapi paths, appending the package name and finally the extension
            //
            foreach (var versioned_item in project_file_reader.packages) {
                var item = versioned_item.split(">=")[0];
                var found = false;
                foreach (var vapi_folder in vapi_folders) {
                    var vapi_file = vapi_folder + item + ".vapi";
                    test_file = File.new_for_path (vapi_file);
                    if (test_file.query_exists ()){
                        debug ("[ValaTools] Adding vapi: %s\n", vapi_file);
                        completion_provider.engine.queue_sourcefile (vapi_file);
                        found = true;
                    }
                }

                if(!found) {
                    warning ("[ValaTools] Vapi file '%s' not found.\n", item);
                }
            }
            
            //
            // Add source files from 'CMakeLists.txt' file
            // Path is formed by appending the current directory to the entry in the project file.
            //
            foreach (var item in project_file_reader.files) {
                var src_file = directory + "/" + item;
                test_file = File.new_for_path (src_file);
                if (test_file.query_exists ()) {
                    debug ("[ValaTools] Adding src file: %s\n", src_file);
                    completion_provider.engine.queue_sourcefile (src_file);
                } else {
                    warning ("[ValaTools] Source file '%s' not found.\n", src_file);
                }
            }
        }
        
        //
        // Configure Gtk.SourceView with the ValaCompletionProvider
        //
        try {
            current_editor.completion.add_provider (completion_provider);
            current_editor.completion.show_headers = true;
            current_editor.completion.show_icons = true;
        } catch (Error e) {
            warning (e.message);
        }
    }

    private void on_end_parsing (Afrodite.CompletionEngine engine) {
        window.toolbar.subtitle = "";
    }
}
