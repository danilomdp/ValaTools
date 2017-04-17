Hello! if you don't know what Vala is, take a look at the project's [homepage](https://wiki.gnome.org/Projects/Vala)\
Scratch is a text editor and part of the elementary OS project. [Project page on Launchpad](https://launchpad.net/scratch)
# Vala language completion for Scratch
This is a contextual completion provider for Scratch in Vala projects, it completes based on the files and packages stated in vala_precompile command inside CMakeLists.txt.
The analyzer used is a library called Afrodite, that is based on the vala compiler itself. It's been modified a little to use with this project.
An important goal is to provide a plugin that is ready to use with current Vala + CMake projects out of the box.

# Dependencies

**Libraries**
* libvala
* libafrodite (modified version)
* scratchcore
* gtk+ & friends
* libpeas
* granite

**Scratch Plugins**
* Folder Manager (shipped with Scratch)
* Outline (shipped with Scratch)

**Optional**
* Patience at the beginning

# Usage
1. Install prerequisites 
1. Clone this repo
1. Check the following variables inside CMakeLists.txt
    1. `SCRATCH_LIB_DIR` should point to the directory that contains the Scratch plugins: `${SCRATCH_LIB_DIR}/scratch/plugins`
    1. `LIB_COMPLETION_HEADER_FOLDER` should point to the directory where libafrodite header is.
1. Create a 'build' folder inside project root, cd to it
1. Run `cmake .. && make && sudo make install`
1. Open `scratch-text-editor`, go to settings > extensions, then enable _Folder Manager_, _Outline_ and _Vala Tools_.
1. Open a project folder with Folder Manager plugin (purple folder icon) it should contain a CMakeLists.txt with _vala\_precompile_ and without _add\_subdirectory_ for now. For example this project is a good example to test the plugin with.
1. Complete!

# Current state
At the moment, the plugin is usable as a context-aware completion provider, but there are some bugs to be fixed. Lots of other features are planned, like:
* Linting (from libafrodite analysis output)
* Multiple CMakeLists projects
* Maybe a run button
* Include Valadoc output