cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)

set (SCRATCH_LIB_DIR /usr/lib/x86_64-linux-gnu)
set (LIB_COMPLETION_HEADER_FOLDER "/usr/local/include/libafrodite-0.34")

include_directories(${LIB_COMPLETION_HEADER_FOLDER})

set (SCRATCH_DEPS
  libpeas-1.0
  libpeas-gtk-1.0
  gtksourceview-3.0
  gee-0.8
  gobject-2.0
  glib-2.0
  gio-2.0
  gtk+-3.0
  gdk-3.0
  scratchcore
  granite>=0.3.0
  libvala-0.34
  libafrodite-0.34)


find_package(PkgConfig)
pkg_check_modules (GTK+ REQUIRED
  gtk+-3.0>=3.10)

pkg_check_modules (LIBSOURCE REQUIRED
  libpeas-gtk-1.0
  gtksourceview-3.0>=3.10
  libvala-0.34
  libafrodite-0.34
  gthread-2.0)

pkg_check_modules (DEPS REQUIRED ${SCRATCH_DEPS})

set(NORMAL_CFLAGS ${DEPS_CFLAGS} ${LIBSOURCE_CFLAGS} ${GCONF_CFLAGS})
set(NORMAL_LINK_DIRS ${DEPS_LIBRARY_DIRS} ${LIBSOURCE_LIBRARY_DIRS} ${GCONF_LIBRARY_DIRS})
set(NORMAL_LIBRARIES ${DEPS_LIBRARIES} ${LIBSOURCE_LIBRARIES} ${GCONF_LIBRARIES})

add_definitions(${NORMAL_CFLAGS})
link_directories(${NORMAL_LINK_DIRS})

add_definitions (${DEPS_CFLAGS} ${LIBSOURCE_CFLAGS} ${GCONF_CFLAGS})
link_libraries (${DEPS_LIBRARIES} ${LIBSOURCE_LIBRARIES} ${GCONF_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS} ${LIBSOURCE_LIBRARY_DIRS} ${GCONF_LIBRARY_DIRS})


set (PLUGIN_NAME "valatools")

set (DEFAULT_PLUGIN_OPTIONS
    --thread
    --target-glib=2.32
)

set (SCRATCHLIB "scratchcore")
set (PLUGINDIR "${CMAKE_INSTALL_FULL_LIBDIR}/scratch/plugins")

link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.22" MINIMUM)
include (ValaPrecompile)

vala_precompile(
    VALA_C ${PLUGIN_NAME}
        src/ValaCompletionProvider.vala
        src/ValaTools.vala
        src/ValaToolsController.vala
        src/ValaCompletionResolver.vala
        src/CMakeValaReader.vala
    PACKAGES
        ${SCRATCH_DEPS}
    OPTIONS
        ${DEFAULT_PLUGIN_OPTIONS} -g -D DEBUG
)

add_library(${PLUGIN_NAME} MODULE ${VALA_C})

install(TARGETS ${PLUGIN_NAME} DESTINATION ${SCRATCH_LIB_DIR}/${PLUGINDIR}/${PLUGIN_NAME})
install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${SCRATCH_LIB_DIR}/${PLUGINDIR}/${PLUGIN_NAME})
message("-- ValaTools for scratch plugin will be prepared")
