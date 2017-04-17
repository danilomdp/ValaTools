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

using Afrodite;

/**
 * Resolves symbols.
 * This class resolves the provided text as a defined symbol or a list of symbols if applicable.
 * It is still in debug process, therefore lots of print() are used
 */
public class ValaCompletionResolver : Object {

    // Each of the components of a fully qualified name (Gtk.Widgets.Window -> ["Gtk", "Widgets", "Window"])
    private string[] components_resolving;
    public CodeDom codedom { get; set; }
    private Symbol this_symbol;
    private int level_resolve = 0;

    public ValaCompletionResolver (CodeDom dom) {
        this.codedom = dom;
    }

    public Vala.List<Symbol>? resolve (Symbol parent, string qualified_name) {
        components_resolving  = split_name(qualified_name.strip ());
        bool get_members = qualified_name.strip ().has_suffix (".");
        this_symbol = climb_to_class(parent);
        print ("\n\033[91m-----------------------------------------------------------------------------------------------\033[1m");
        print ("\n\033[91m----------------------------- Completion request: resolving -----------------------------------\033[1m");
        print ("\n\033[91m-----------------------------------------------------------------------------------------------\033[1m\n");
        return resolve_component (listify (parent), components_resolving, 0, get_members);
    }

    #if DEBUG
    public void print_list (string title, Vala.List<Symbol>? s) {
        var Color_Off="\033[0m";
        var Red="\033[91m";
        var Green="\033[96m";
        var Blue="\033[94m";
        var Bold="\033[1m";
        print (@"$Bold$Green [[%s]]$Color_Off", title);
        if(s==null) {
            print (@"\t$Bold$Red NULL list$Color_Off\n");
            return;
        }

        if(s.size == 0) {print (@"\t$Red Empty list$Color_Off\n"); return;}
        print ("\n");
        foreach (var item in s) {
            if (item==null) { print (@"\t$Red NULL item in list$Color_Off\n"); continue; }
            print(@"\t+ $Blue%-50s$Color_Off$Bold:$Color_Off (%s) [%-30s]\n", item.name==null?"NULL NAME!!!":item.name, item.symbol_type==null?@"\033[91mNULL$Color_Off":item.symbol_type.type_name, item.member_type.to_string ());
        }
    }
    #endif

    /**
    * Resolve a step from a fully qualified name
    * @param target The parent symbol where the text being resolved belongs
    * @param components String array of the fully qualified name elements separated by dot
    */
    public Vala.List<Symbol>? resolve_component (Vala.List<Symbol> targets, string[] components, int step, bool get_members, bool strict = false) {
        level_resolve++;
        #if DEBUG
        print(@"\033[1;91m[Step $step] (%d components) ---------------------------------\033[0m\ntargets.length: %d, targets[0] : %s, mode: %s\n", 
        components.length, targets.size, (targets[0].symbol_type!=null)?targets[0].symbol_type.type_name: "NULL", strict?"strict":"non-strict");
        #endif
        Symbol target;
        if (targets[0]!=this_symbol && targets[0].symbol_type!=null && targets[0].symbol_type.symbol!=null) {
            target = targets[0].symbol_type.symbol;
        } else {
            target = targets[0];
        }
        // Symbol target = targets[0];
        // Solved! get the requested items
        if (step > components.length-1) {
            #if DEBUG
            print ("\t\033[94mlast+1\033[0m ");
            #endif
            if(get_members) {
                #if DEBUG
                print ("getting members of %s\n", target.name);
                print_list ("END target contents", target.children);
                #endif
                if (target != this_symbol && target.symbol_type!=null && target.symbol_type.symbol!=null) {
                    #if DEBUG
                    print ("\033[91mLooking inside symbol\033[0m\n");
                    level_resolve--;
                    #endif
                    return target.symbol_type.symbol.children;
                }
                level_resolve--;
                return target.children;
            } else {
                #if DEBUG
                print ("returning suggestions\n");
                print_list ("END targets", targets);
                level_resolve--;
                #endif
                return targets;
            }
        }

        // The component to match in target
        string component = components[step];
        #if DEBUG
        print ("Current component: \033[1m%s\033[0m\n", component);
        #endif

        // Normalize if component is a method call. (Get method name)
        if (component.contains("(")) {
            // TODO: select adequate method from argument types
            var method_call = normalize_method_call (component);
            component = method_call;
        }

        // Resolve the first component
        if (step == 0) {
            var all_results = new Vala.ArrayList<Symbol>();
            // 0. Is the first component the keyword "this"?
            if(component == "this") {
                #if DEBUG
                print (@"\033[94mTHIS! $step\033[0m\n");
                level_resolve--;
                #endif
                var this_based_results = resolve_component (listify (this_symbol), components, step+1, get_members);
                append_symbol_list (all_results, this_based_results);
            }

            var cmode = (components.length==1 && (!strict))?CompareMode.STARTS_WITH:CompareMode.EQUALS;

            // 1. Is it a local variable?
            var locals = search_locals (targets[0], component, cmode);
            #if DEBUG
            print_list (@"Locals : $step", locals);
            #endif
            if(locals.size > 0){
                level_resolve--;
                var local_results = resolve_component (locals/*listify (locals[0].symbol_type.symbol)*/, components, step+1, get_members);
                append_symbol_list (all_results, local_results);
            }

            // 2. Is it inside 'this'?
            var this_components = search_inside_symbol (this_symbol, component, cmode);
            #if DEBUG
            print_list(@"this_components : $step", this_components);
            #endif
            if(this_components.size > 0){
                level_resolve--;
                var this_results = resolve_component (this_components/*listify (this_components[0].symbol_type.symbol)*/, components, step+1, get_members);
                append_symbol_list (all_results, this_results);
            }

            // 3. Is it a type defined in the current project?
            var project_types = search_as_project_type (component, cmode);
            #if DEBUG
            print_list (@"project_types : $step", project_types);
            #endif
            if(project_types.size > 0){
                level_resolve--;
                var project_results = resolve_component (project_types/*listify (project_types[0].symbol_type.symbol)*/, components, step+1, get_members);
                append_symbol_list (all_results, project_results);
            }

            // 4. Is it an included namespace or member of one of those?
            var used_namespaces = search_in_used_namespaces (this_symbol, component, cmode);
            #if DEBUG
            print_list (@"used_namespaces : $step", used_namespaces);
            #endif
            if(used_namespaces.size > 0){
                level_resolve--;
                var ns_results = resolve_component (used_namespaces/*used_namespaces[0].symbol_type.symbol*/, components, step+1, get_members);
                append_symbol_list (all_results, ns_results);
            }

            // TODO: 5. Is a root namespace in the project packages not explicitly included with 'using'

            return all_results;
        } 

        // Look inside the last resolved symbol, and call self with the result
        var results = search_inside_symbol (target, component, (step == components.length-1)?CompareMode.STARTS_WITH:CompareMode.EQUALS);
        #if DEBUG
        print_list ("middle results", results);
        #endif
        if(results.size > 0) {
            level_resolve--;
            return resolve_component (results, components, step+1, get_members, strict);
        }
        level_resolve--;
        return null;
    }

      //                //
     // Search methods //
    //                //

    /**
    * Look name inside symbol
    * @param s The symbol to look inside
    * @param name The name to find as prefix within
    * @return A list (@see Vala.List<Symbol>) of matched symbols
    */
    public Vala.List<Symbol> search_inside_symbol (Symbol? s, string name, CompareMode cmode = CompareMode.EQUALS) {
        Vala.List<Symbol> results = new Vala.ArrayList<Symbol> ();
        if(s==null){
            #if DEBUG
            print ("search_inside_symbol, NULL Symbol provided!!!!!!! \033[91mERROR!!!!\033[0m\n");
            #endif
            return results;
        }
        foreach (var item in s.children) {
            if(compare_names (item.name, name, cmode)) {
                results.add (item);
            }
        }
        return results;
    }

    /**
    * Look name inside symbol's local variables
    * @param s The symbol to look its local variables
    * @param name The name to find as prefix within locals
    * @return A list (@see Vala.List<Symbol>) of matched and resolved symbols
    */
    public Vala.List<Symbol> search_locals (Symbol s, string name, CompareMode cmode = CompareMode.EQUALS) {
        Vala.List<Symbol> locals = new Vala.ArrayList<Symbol> ();
        var current_symbol = s;
        // Get variables inside language constructs (if, for, ..., etc), inside the symbol
        while (current_symbol.member_type == MemberType.SCOPED_CODE_NODE) {
            append_symbol_list (locals, search_locals_inside (current_symbol, name, cmode));
            current_symbol = current_symbol.parent;
        }

        // Search in the current local context
        append_symbol_list (locals, search_locals_inside (current_symbol, name, cmode));
        // If a method, search inside the arguments
        if (current_symbol.member_type == MemberType.METHOD){
            append_symbol_list (locals, search_in_method_args (current_symbol, name, cmode));
        }

        return locals;
    }

    /**
    * Look name inside symbol's first level local variables
    * @param s The symbol to look its local variables
    * @param name The name to find as prefix within locals
    * @return A list (@see Vala.List<Symbol>) of matched and resolved symbols
    */
    private Vala.List<Symbol> search_locals_inside (Symbol s, string name, CompareMode cmode = CompareMode.EQUALS) {
        Vala.List<Symbol> locals = new Vala.ArrayList<Symbol> ();
        if (!s.has_local_variables) { return locals; }
        foreach (DataType loc in s.local_variables) {
            if (compare_names (loc.name, name, cmode)) {
                var loc_sym = loc.symbol;
                
                if (loc_sym==null) { warning ("[CompletionResolver search_locals_inside] Oh! a null symbol\n"); continue;}
                
               
                print ("loc: %s, type_name: %s : %s\n", loc.name, loc.type_name, loc.unresolved?"UNRESOLVED":"resolved");
                print ("loc_sym: %s, fully_qualified_name: %s [%s]\n", loc_sym.name, loc_sym.fully_qualified_name, loc_sym.member_type.to_string ());
                print ("loc_sym.symbol_type.name: %s, loc_sym.symbol_type.type_name: %s\n", loc_sym.symbol_type.name, loc_sym.symbol_type.type_name);
                loc_sym.name = loc.name;
                loc_sym.symbol_type = loc;
                loc_sym.symbol_type.name = loc_sym.name;
                loc_sym.symbol_type.type_name = loc_sym.name;
                locals.add (loc_sym);
            }
        }
        return locals;
    }

    /**
    * Look name inside project data types
    * @param name The name to find as prefix within
    * @return A list (@see Vala.List<Symbol>) of matched symbols
    */
    public Vala.List<Symbol> search_as_project_type (string name, CompareMode cmode = CompareMode.EQUALS) {
        Vala.List<Symbol> types = new Vala.ArrayList<Symbol>();
        foreach (var file in codedom.source_files) {
            if(file.filename.has_suffix (".vapi")){
                continue;
            }

            foreach (var fsym in file.symbols) {
                if(test_if_class_alike (fsym) && compare_names (fsym.name, name, cmode)) {
                    types.add (fsym);
                }
            }
        }

        #if DEBUG
        print("\033[94m[search_as_project_type]\033[0m Search inside project types\n");
        print_list ("project types", types);
        #endif
        return types;
    }

    /**
    * Look name inside current file's 'using' namespaces
    * @param s The symbol to look inside
    * @param name The name to find as prefix within
    * @return A list (@see Vala.List<Symbol>) of matched symbols
    */
    public Vala.List<Symbol> search_in_used_namespaces (Symbol s, string name, CompareMode cmode = CompareMode.EQUALS) {
        Vala.List<Symbol> results = new Vala.ArrayList<Symbol>();
        var src_file = s.source_references[0].file;
        var usings = src_file.using_directives;
        foreach (DataType ns in usings) {
            // 1. Look if it's the same name
            if (compare_names (ns.type_name, name, cmode)) {
                results.add (ns.symbol);
            }

            // 2. Look inside the Namespace
            if (ns.symbol != null && ns.symbol.has_children) {
                foreach (Symbol nsitem in ns.symbol.children) {
                    if (compare_names (nsitem.name, name, cmode)) {
                        print ("found inside namespace: %s\n", nsitem.name);
                        results.add (nsitem);
                    }
                }
            }
        }
        return results;
    }

    /**
    * Search if name matches a method argument name
    * @param method Symbol to query name
    * @param name String to match a method argument
    * @param cmode compare mode to match depending the step
    */
    public Vala.List<Symbol> search_in_method_args (Symbol method, string name, CompareMode cmode) {
        if (method.member_type != MemberType.METHOD) {
            print ("[search_in_method_args] not a method\n");
            // TODO: return null
            return new Vala.ArrayList<Symbol> ();
        }

        Vala.List<Symbol> args = new Vala.ArrayList<Symbol> ();
        foreach (var arg in method.parameters) {
            if (!arg.unresolved && arg.symbol!=null && compare_names (arg.name, name, cmode)) {
                #if DEBUG
                print ("\tmethod \033[94m'%s'\033[0m resolved argument %s (%s) \t symbol is %s\n", method.name, arg.type_name, arg.name, arg.symbol==null?"NULL":arg.symbol.name);
                #endif
                arg.symbol.name = arg.name;
                args.add (arg.symbol);
            } else {
                //print ("\tmethod \033[94m'%s'\033[0m UNRESOLVED argument %s (%s)\n", method.name, arg.type_name, arg.name);
            }
        }

        return args;
    }

    //   ---------
    // ||(Section)||
    // ||# Utils  ||
    //   ---------

    /**
    * Get method call components, from a string of the form "method_name (arg0, arg1, ...)"
    * @param method_call String with the method call syntax.
    * @return At index 0 the method name, the next indices contain each argument passed. 
    *         If the pattern is not met, the result is the same input
    */
    public string normalize_method_call (string method_call) {
        string element = method_call;
        var arg_regex = new Regex ("([\\d\\w\\_]+)(\\([\\d\\w\\ \\t\\,\\=\\\"\\'\\@\\&\\*\\.\\<\\>\\_\\-\\+\\!\\?\\&\\/]*\\))");

        MatchInfo mtch;
        var name_with_parenthesis = arg_regex.match(element, 0, out mtch);
        while ( mtch.matches () ) {
            try {
                var fnname = mtch.fetch (1);
                if (fnname != null) {
                    element = fnname.strip();
                    break;
                }
                mtch.next ();
            } catch (RegexError err) {
                debug ("[ValaNameResolver > normalize_method_call] Method matching Regex Error!\n");
            }
        }

        return element;
    }

    /**
    * Split by dot, remove trailing empty string if line ends with dot.
    * @param fully_qualified_name
    * @return An array of strings, corresponding to each component in the provided name 
    */
    private string[] split_name (string fully_qualified_name) {
       var components = fully_qualified_name.split(".");
       if (components.length > 2) {
           if (components[components.length-1].strip() == "") {
               return components[0:components.length-1];
           } else {
               return components;
           }
       } else {
           if (components.length == 2 && components[1].strip() == "") {
               return new string[] {components[0].strip()};
           }
       }
       #if DEBUG
       foreach (var item in components) {
           print("\t[split_name] > " + item + "\n");
       }
       #endif
       return components;
    }

    /**
    * Get what is 'this' from a given Symbol (i.e. given a method, to what class does it belong)
    * @param s The symbol inside a class, interface or struct 
    * @return The top level class/interface/struct that contains the symbol s
    */
    public Symbol? climb_to_class (Symbol s) {
        var current_symbol = s;
        while (current_symbol!=null) {
            //print("\033[1mNow: %s\033[0m [%s]\n", current_symbol.name, current_symbol.member_type.to_string ());
            if (current_symbol.member_type == MemberType.CLASS) {
                return current_symbol;
            }
            current_symbol = current_symbol.parent;
        }
        //print ("\033[1mOoops, NULL current_symbol\033[0m\n");
        return null;
    }

    /**
    * Is the given symbol a Class, Interface or Struct?
    * @param The symbol to test
    * @return *true* if is a Class, Interface or Struct. *false* otherwise.
    */
    private bool test_if_class_alike (Symbol s) {
        return s.member_type==MemberType.CLASS || s.member_type==MemberType.INTERFACE || s.member_type==MemberType.STRUCT;
    }

    /**
    * Convenience method
    * @param s Symbol to encapsulate inside a @see Vala.List<Symbol>
    * @return A @see Vala.List<Symbol> containing the single symbol s
    */
    public Vala.List<Symbol> listify (Symbol s) {
        var list = new Vala.ArrayList<Symbol> ();
        list.add (s);
        return list;
    }

   /**
    * Append list to a list
    * @param list A Vala.List<Symbol> to extend by appending other
    * @param tail A Vala.List<Symbol> to append
    */   
    private void append_symbol_list (Vala.List<Symbol> list, Vala.List<Symbol> tail) {
        if(list!=null && tail!=null && tail.size > 0){
            // Ok, not the best way
            // TODO: do a better append, maybe using Gee.LinkedList or defining Vala.LinkedList for compatibility
            foreach (var item in tail) {
                list.add(item);
            }
        }
    }

    /**
    * Compare two strings exactly or partially
    * @param name1 reference name
    * @param name2 test name
    * @param mode Compare mode
    * @return true if strings match with the given mode, false otherwise
    */
    private bool compare_names (string? name1, string? name2, CompareMode mode) {
        if(name1==null || name2==null){
            print ("\t!!!!!! null name, where that comes from?\n");
            //breakpoint();
            return false;
        }
        if(mode==CompareMode.EQUALS){
            return name1==name2;
        } else {
            return name1.has_prefix (name2);
        }
    }

    public enum CompareMode {
        EQUALS,
        STARTS_WITH
    }
}
