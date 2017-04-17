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

public class CMakeValaReader : GLib.Object { 
    public string code_content;
    public Gee.TreeMap<string, Gee.List<string>> cmake_definitions;
    public Gee.List<string> unres_files;
    public Gee.List<string> files;
    public Gee.List<string> unres_packages;
    public Gee.List<string> packages;
    
    public CMakeValaReader() {
        
    }

    public bool parse_file (string path) {
        if(!read_file (path)){ return false; }

        cmake_definitions = new Gee.TreeMap<string, Gee.List<string>> ();
        files = new Gee.ArrayList<string> ();
        packages = new Gee.ArrayList<string> ();
        unres_files = new Gee.ArrayList<string> ();
        unres_packages = new Gee.ArrayList<string> ();
        
        read_variables ();
        return read_vala_precompile ();
    }

    private bool read_vala_precompile () {
        var vala_precomp = find_cmake_command ("vala_precompile");
        if(vala_precomp.size==0){ warning ("There is no vala_precompile\n"); return false;}
        var vala_args = split_command_args (vala_precomp[0]);
        var vala_state = 0;
        foreach (var item in vala_args) {
            item = item.strip ();
            switch (vala_state) {
                case 0:
                vala_state = 1; break;
                case 1: // Target name
                vala_state = 2;
                break;
                case 2:
                   if(item=="PACKAGES") {
                       vala_state = 3;
                   } else {
                       unres_files.add (item);
                   }
                break;
               case 3:
                   if (item=="TARGET" || item=="OPTIONS" || item=="TYPELIB_OPTIONS" || item=="DIRECTORY" 
                        || item=="GENERATE_GIR" || item=="GENERATE_SYMBOLS" || item=="GENERATE_HEADER" || item=="GENERATE_VAPI" 
                        || item=="CUSTOM_VAPIS" || item=="DEPENDS" 
                        || item=="LIBRARY"
                        ) {
                       vala_state = 4;
                       break;
                   }
                   unres_packages.add (item);
               break;
            default:
                break;
            }
        }

        foreach (var item in unres_files) {
            var res = resolve_cmake_var(item);
            if(res==null){
                print ("file: %s\n", item);
                files.add (item);
            } else {
                this.files = res;
                foreach (var i2 in files) {
                    print("file*: %s\n", i2);
                }
                continue;
            }
        }
 
        print ("-----------------------------------\n");
        foreach (var item in unres_packages) {
            var res = resolve_cmake_var(item);
            if(res==null){
                print ("pkg: <<%s>>\n", item);
                packages.add (item);
            } else {
                packages = res;
                foreach (var i2 in packages) {
                    print("pkg*: <<%s>>\n", i2);
                }
            }
        }
        return true;
    }

    private void read_variables () {
        var set_commands = find_cmake_command ("set");
        foreach (var cmd in set_commands) {
            var arg_list = split_command_args (cmd.strip ());
            var var_name = arg_list[0];
            if (arg_list.size >= 2) {
                arg_list.remove_at (0);
                cmake_definitions.@set (var_name.strip(), arg_list);
            }
        }
    }

    private Gee.List<string>? resolve_cmake_var (string expression) {
        try {
            var varegex = new Regex ("\\$\\{([\\d\\w]+)\\}");
            MatchInfo mtchinfo;
            var matched = varegex.match (expression, 0, out mtchinfo);
            if(matched) {
                var vname = mtchinfo.fetch(1);
                var vvalue = cmake_definitions.@get(vname.strip());
                return vvalue;
            }
        } catch (RegexError err){
            error ("[ValaTools CMakeValaReader resolve_cmake_var()] Regex error");
        }
        return null;
    }

    private bool read_file (string path) {
        var file = File.new_for_path (path); 

        if (!file.query_exists ()) {
            stderr.printf ("File '%s' doesn't exist.\n", file.get_path ());
            return false;
        }
        string all_text = "";
        try {
            // Open file for reading and wrap returned FileInputStream into a
            // DataInputStream, so we can read line by line
            var dis = new DataInputStream (file.read ());
            string line;
            // Read lines until end of file (null) is reached
            while ((line = dis.read_line (null)) != null) {
                all_text += line + "\n";
            }
            this.code_content = all_text;
        } catch (Error e) {
            error ("%s", e.message);
        }
        return true;
    }

    public Gee.List<string> find_cmake_command (string command_name) {
        Gee.List<string> results = new Gee.LinkedList<string> ();
        MatchInfo mtch;
        string element = this.code_content;
        try {
            var vala_command_regex = new Regex ("(?s)" + command_name + "[\\ \\t]*\\(([\\d\\w\\s\\$\\_\\-\\{\\}\\.\\/\\+\\\"\\'\\<\\>\\=]*)\\)", RegexCompileFlags.DOTALL | RegexCompileFlags.NEWLINE_ANYCRLF  | RegexCompileFlags.MULTILINE);
         
            var matched = vala_command_regex.match(element, 0, out mtch);
            if(matched){print("matched\n");}else {print("no match\n");}
            
            while ( mtch.matches () ) {
                var fnname = mtch.fetch (1);
                if (fnname != null) {
                    element = fnname.strip();
                    results.add (element);
                }
                mtch.next ();
            }
        } catch (RegexError err) {
            error ("[CMakeValaReader > normalize_method_call] Method matching Regex Error!\n");
        }
        return results;
    }

    public Gee.List<string> split_command_args (string whole_arg_) {
        string whole_arg = whole_arg_.strip ();
        var in_string = false;
        var in_escape = false;
        var i = 0;
        char c = ' ';  
        var break_points = new Gee.LinkedList<int> ();
        var last_bp = -2;
        var res = new Gee.LinkedList<string> ();
        #if DEBUG
        print ("Analyzing args from:\n\t%s\n", whole_arg);
        #endif
        while (i < whole_arg.length) {
            c = whole_arg[i];

            if (!in_string) {
                if (c=='"'){
                    in_string = true;
                    in_escape = false;
                } else if (c==' ' || c=='\n') {
                    if(last_bp!=(i-1)){
                        break_points.add (i);
                    }
                    last_bp = i;
                }
            } else if (in_escape) {
                in_escape = false;
            } else {
                if (c=='\\') {
                    in_escape = true;
                } else if (c=='"'){
                    in_string = false;
                    in_escape = false;
                }
            }
            i++;
        }
        break_points.add (whole_arg.length);
        last_bp = 0;
        foreach (var bp in break_points) {
            var slice = whole_arg.substring (last_bp, bp-last_bp);
            #if DEBUG
            //print ("Argument element: %s\n", slice);
            #endif
            res.add (slice.strip ());
            last_bp = bp;
        }
        
        print ("----------------------------\n");
        return res;
    }

    public static void main (string[] args) {
        print ("testing CMakeLists parser\n");
        var reader = new CMakeValaReader ();
        var path = "../CMakeLists.txt";
        if(args.length>=2){
            path = args[1];
        }
        reader.parse_file (path);
    }
}
