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
using Gdk;
using Afrodite;

/**
 * This class is part of the Gtk.SourceView completion architecture.
 * Here the proposals are fed to the popup view
 */
public class Scratch.Plugins.ValaCompletionProvider : SourceCompletionProvider, GLib.Object {

    public ValaToolsController  pluginc;
    public Afrodite.CompletionEngine engine {get; set;}

    public ValaCompletionProvider (ValaToolsController c) {
        this.pluginc = c;
        this.engine = new Afrodite.CompletionEngine ("vala-tools-completer");
    }

    public bool activate_proposal (SourceCompletionProposal proposal, TextIter iter) { 
        return false;
    }

    public unowned string? get_icon_name () {
        return "applications-development";
    } 

    public SourceCompletionActivation get_activation () { return SourceCompletionActivation.USER_REQUESTED;}

	public unowned Widget? get_info_widget (SourceCompletionProposal proposal) { return null; }

	public int get_interactive_delay () { return -1; }

	public string get_name () {
	    return "Vala";
	}

	public int get_priority () {
	    return 200;
	}

	public bool get_start_iter (SourceCompletionContext context, SourceCompletionProposal proposal, out TextIter iter) {
	    return false; 
	}

    public bool match (SourceCompletionContext context) { return true; }

    /**
     * = Populate proposal list =
     *
     * 1. Get the 'completable' text
     * 2. TODO: Check if a snippet or keyword applies (not implemented yet)
     * 3. Using a CompletionResolver offer completions
     */
    public void populate (SourceCompletionContext context) {
        var compl_iter = context.iter;
        var line_end_iter = compl_iter;
        line_end_iter.forward_to_line_end ();
                
        var line_start_iter = compl_iter;
        line_start_iter.backward_line ();
        line_start_iter.forward_to_line_end();

        var char_stop_iter = compl_iter;
        var level = 0;
        var pos = 0;

        var linetext = line_start_iter.get_slice (compl_iter);

        var positions = new List<int>();
        positions.append(0);

        /**
         * Get the last non balanced opening parenthesis
         */
        for (int i = 0; i<linetext.length; i++) {
            var ltr = linetext[i];
            if(ltr=='('){
                level++;
                pos = i;
                positions.append(i);
            } else if (ltr==')') {
                level--;
                if(level>0){
                    positions.remove_link(positions.last());
                }
            }
        }

        print("Level " + level.to_string() + "\n");

        // A negative level indicates unbalanced closing parenthesis
        // This case breaks the collecting process, because the resulting id would be ')name.split(...)'
        if(level < 0) {
            level = 0;
        }

        /**
         * Scan backwards from the completion point until a non id character is met.
         * But if the non id character is '(' or ')' check if it (specially the opening one)
         * is the non balanced one or a method call, if the first case applies, then there is the 'completable' id
         */
        var loop_on_char = true;
        var c_at = char_stop_iter.get_char ();
        while ( ( (char_stop_iter.get_offset() - line_start_iter.get_offset()) > positions.nth_data(level) ) && loop_on_char ) {
            while ( c_at.isalnum () || c_at == '.' || c_at.isspace () || c_at == '_' ){
                char_stop_iter.backward_char ();
                c_at = char_stop_iter.get_char ();
                print("backward_char result is:\t" + c_at.to_string () + "\n");
            }

            loop_on_char = (c_at=='(' || c_at==')');
            if (loop_on_char && (char_stop_iter.get_offset() - line_start_iter.get_offset()) > positions.nth_data(level)) {
                char_stop_iter.backward_char ();
                c_at = char_stop_iter.get_char ();
            }
        }

        // We are at the non id character, advance to the last, that is part of the id
        char_stop_iter.forward_char ();

        // -------------------------------------------------------
        // Get completions for code slice from current cursor
        // -------------------------------------------------------

        var id_text = char_stop_iter.get_slice (compl_iter).strip ();
        var current_path = this.pluginc.current_document.file.get_path();

        debug ("[Vala Tools] Text to analyze:\n" + id_text + "\n#end\n");

        var current_symbol_ = this.engine.codedom.lookup_symbol_at (
                current_path, 
                compl_iter.get_line(),
                compl_iter.get_line_offset() );

        var resolver = new ValaCompletionResolver (this.engine.codedom);
        var proposals = resolver.resolve ((Symbol)current_symbol_, id_text);

        if(proposals==null) {
            debug ("[ValaTools CompletionProvider] NO PROPOSALS !!!!!!!\n");
            return;
        }

        List<SourceCompletionProposal> src_proposals = new List<SourceCompletionProposal>();
        foreach (var item in proposals) {
            var info = "";

            if(item.member_type == MemberType.METHOD) {
                info = "Arguments:\n";
                foreach (var argf in item.parameters) {
                    info+=(argf.name + " : " + argf.type_name + "\n");
                }
            }

            var type = "";
            if (item.symbol_type==null) {
                if (item.member_type == MemberType.NAMESPACE) {
                    type = "{Namespace}";
                } else if (item.member_type == MemberType.STRUCT) {
                    type = "{Struct}";
                } else {
                    type = "*Unresolved*";
                }
            } else {
                type = item.symbol_type.type_name;
            }

            src_proposals.append(
                new SourceCompletionItem.with_markup (
                    item.name + " <span foreground=\"gray\"><i>" + type + "</i></span>", item.name, 
                    get_icon_for_type(item.member_type), info+"\n"+item.fully_qualified_name
                ));
        }
        context.add_proposals (this, src_proposals, true);        
    }


    public Pixbuf get_icon_for_type (MemberType type) {
        Gdk.Pixbuf pix = null;
        try {
            switch (type) {
                case MemberType.NONE:
                break;
                case MemberType.VOID:
                break;
                case MemberType.CONSTANT:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-constant.svg");
                break;
                case MemberType.ENUM:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-enum.svg");
                break;
                case MemberType.ENUM_VALUE:
                break;
                case MemberType.FIELD:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-property.svg");
                break;
                case MemberType.PROPERTY:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-property.svg");
                break;
                case MemberType.LOCAL_VARIABLE:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-property.svg");
                break;
                case MemberType.SIGNAL:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-signal.svg");
                break;
                case MemberType.CREATION_METHOD:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-constructor.svg");
                break;
                case MemberType.CONSTRUCTOR:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-constructor.svg");
                break;
                case MemberType.DESTRUCTOR:
                break;
                case MemberType.METHOD:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-method.svg");
                break;
                case MemberType.DELEGATE:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-delegate.svg");
                break;
                case MemberType.PARAMETER:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-property.svg");
                break;
                case MemberType.TYPE_PARAMETER:
                break;
                case MemberType.ERROR_DOMAIN:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-error-domain.svg");
                break;
                case MemberType.ERROR_CODE:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-erro-domain.svg");
                break;
                case MemberType.NAMESPACE:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-namespace.svg");
                break;
                case MemberType.STRUCT:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-struct.svg");
                break;
                case MemberType.CLASS:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-class.svg");
                break;
                case MemberType.INTERFACE:
                    pix = new Pixbuf.from_resource("/org/pantheon/scratch/plugin/outline/lang-interface.svg");
                break;
                default:
                    break;
            }
            if(pix==null){
                var img = new Gtk.Image.from_icon_name ("package-x-generic", Gtk.IconSize.MENU);
                pix = img.pixbuf;
            }
        } catch (Error err) {
            error ("Activate the Outline extension, if it is already, please tell the developer that icons are not available by filing an issue on GitHub. Thanks!");
        }
        return pix;
    }

    public void update_info (SourceCompletionProposal proposal, SourceCompletionInfo info){ return; }
}
