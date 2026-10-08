Name:           hyprland
Version:        0.56.2
Release:        2%{?dist}
Summary:        Dynamic tiling Wayland compositor

License:        BSD-3-Clause
URL:            https://hypr.land/

%global hyprland_protocols_version 0.7.0
%global glaze_version 7.2.0
%global aquamarine_version 0.15.1
%global hyprwayland_scanner_version 0.4.6
%global hyprutils_version 0.14.2
%global hyprlang_version 0.6.8
%global hyprcursor_version 0.1.13
%global hyprgraphics_version 0.5.1
%global lua_version 5.5.1
%global lua_abi 5.5
%global hyprwire_version 0.3.1
%global hyprtoolkit_version 0.6.0
%global guiutils_version 0.2.2
%global portal_version 1.4.1
%global hyprland_commit efb50993780079460b0cbed1363e2166a2de1d9f
%global __requires_exclude pkgconfig\\((aquamarine|hyprutils|hyprlang|hyprcursor|hyprgraphics|hyprwayland-scanner|hyprland-protocols|hyprwire)\\)

Source0:        https://github.com/hyprwm/Hyprland/archive/refs/tags/v%{version}.tar.gz
# Tagged upstream dependency releases compatible with Hyprland 0.56.2.
Source10:       https://github.com/hyprwm/hyprland-protocols/archive/refs/tags/v%{hyprland_protocols_version}.tar.gz#/hyprland-protocols-%{hyprland_protocols_version}.tar.gz
Source20:       https://github.com/stephenberry/glaze/archive/refs/tags/v%{glaze_version}.tar.gz#/glaze-%{glaze_version}.tar.gz
Source21:       https://github.com/hyprwm/aquamarine/archive/refs/tags/v%{aquamarine_version}.tar.gz#/aquamarine-%{aquamarine_version}.tar.gz
Source22:       https://github.com/hyprwm/hyprwayland-scanner/archive/refs/tags/v%{hyprwayland_scanner_version}.tar.gz#/hyprwayland-scanner-%{hyprwayland_scanner_version}.tar.gz
Source23:       https://github.com/hyprwm/hyprutils/archive/refs/tags/v%{hyprutils_version}.tar.gz#/hyprutils-%{hyprutils_version}.tar.gz
Source24:       https://github.com/hyprwm/hyprlang/archive/refs/tags/v%{hyprlang_version}.tar.gz#/hyprlang-%{hyprlang_version}.tar.gz
Source25:       https://github.com/hyprwm/hyprcursor/archive/refs/tags/v%{hyprcursor_version}.tar.gz#/hyprcursor-%{hyprcursor_version}.tar.gz
Source26:       https://github.com/hyprwm/hyprgraphics/archive/refs/tags/v%{hyprgraphics_version}.tar.gz#/hyprgraphics-%{hyprgraphics_version}.tar.gz
Source27:       https://www.lua.org/ftp/lua-%{lua_version}.tar.gz
Source28:       https://github.com/hyprwm/hyprwire/archive/refs/tags/v%{hyprwire_version}.tar.gz#/hyprwire-%{hyprwire_version}.tar.gz
Source29:       https://github.com/hyprwm/hyprtoolkit/archive/refs/tags/v%{hyprtoolkit_version}.tar.gz#/hyprtoolkit-%{hyprtoolkit_version}.tar.gz
Source30:       https://github.com/hyprwm/hyprland-guiutils/archive/refs/tags/v%{guiutils_version}.tar.gz#/hyprland-guiutils-%{guiutils_version}.tar.gz
Source31:       https://github.com/hyprwm/xdg-desktop-portal-hyprland/archive/refs/tags/v%{portal_version}.tar.gz#/xdg-desktop-portal-hyprland-%{portal_version}.tar.gz

# Requirements verified with a clean Fedora 44 Mock build.
BuildRequires:  cmake
BuildRequires:  abseil-cpp-devel
BuildRequires:  cairo-devel
BuildRequires:  file-devel
BuildRequires:  gcc-c++
BuildRequires:  glslang-devel
BuildRequires:  hwdata-devel
BuildRequires:  iniparser-devel
BuildRequires:  libglvnd-devel
BuildRequires:  libinput-devel >= 1.26.0
BuildRequires:  libjpeg-turbo-devel
BuildRequires:  libdrm-devel
BuildRequires:  libdisplay-info-devel
BuildRequires:  libeis-devel
BuildRequires:  libffi-devel
BuildRequires:  libseat-devel >= 0.8.0
BuildRequires:  libuuid-devel
BuildRequires:  libwebp-devel
BuildRequires:  libXcursor-devel
BuildRequires:  libxkbcommon-devel >= 1.11.0
BuildRequires:  librsvg2-devel
BuildRequires:  libzip-devel
BuildRequires:  mesa-libgbm-devel
BuildRequires:  muParser-devel
BuildRequires:  ninja-build
BuildRequires:  pango-devel
BuildRequires:  pipewire-devel >= 1.1.82
BuildRequires:  pixman-devel
BuildRequires:  pugixml-devel
BuildRequires:  re2-devel
BuildRequires:  readline-devel
BuildRequires:  sdbus-cpp-devel >= 2.0.0
BuildRequires:  systemd-rpm-macros
BuildRequires:  tomlplusplus-devel
BuildRequires:  udis86-devel >= 1.7.2
BuildRequires:  wayland-devel
BuildRequires:  wayland-protocols-devel
BuildRequires:  xcb-util-errors-devel
BuildRequires:  xcb-util-wm-devel
BuildRequires:  qt6-qtbase-devel

Requires:       xorg-x11-server-Xwayland
Recommends:     uwsm
Recommends:     hyprland-guiutils
Recommends:     xdg-desktop-portal-hyprland

%description
Hyprland is a dynamic tiling Wayland compositor with extensive customization,
powerful plugins, and modern Wayland features. Upstream Hypr libraries are
built from compatible tagged releases and kept in a private runtime directory
to avoid conflicts with system libraries.

%package -n hyprland-guiutils
Summary:        Native GUI utilities for Hyprland
Requires:       %{name}%{?_isa} = %{version}-%{release}
Provides:       hyprland-guiutils-upstream = %{guiutils_version}

%description -n hyprland-guiutils
Native GUI helpers used by Hyprland for dialogs, update and donation screens,
the welcome interface, and command execution.

%package -n xdg-desktop-portal-hyprland
Summary:        XDG Desktop Portal backend for Hyprland
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       pipewire
Requires:       qt6-qtbase-gui
Requires:       xdg-desktop-portal
Provides:       xdg-desktop-portal-hyprland-upstream = %{portal_version}

%description -n xdg-desktop-portal-hyprland
Hyprland portal backend providing screen casting, screenshots, global
shortcuts, settings, file chooser integration, and input capture.

%prep
%autosetup -n Hyprland-%{version}
rm -rf subprojects/hyprland-protocols
tar -xzf %{SOURCE10} -C subprojects
mv subprojects/hyprland-protocols-%{hyprland_protocols_version} subprojects/hyprland-protocols
tar -xzf %{SOURCE20}
tar -xzf %{SOURCE21}
tar -xzf %{SOURCE22}
tar -xzf %{SOURCE23}
tar -xzf %{SOURCE24}
tar -xzf %{SOURCE25}
tar -xzf %{SOURCE26}
tar -xzf %{SOURCE27}
tar -xzf %{SOURCE28}
tar -xzf %{SOURCE29}
tar -xzf %{SOURCE30}
tar -xzf %{SOURCE31}
rm -rf xdg-desktop-portal-hyprland-%{portal_version}/subprojects/hyprland-protocols
cp -a subprojects/hyprland-protocols xdg-desktop-portal-hyprland-%{portal_version}/subprojects/

%build
VENDOR_PREFIX="$PWD/vendor"
mkdir -p "$VENDOR_PREFIX"
export CMAKE_PREFIX_PATH="$VENDOR_PREFIX"
export PKG_CONFIG_PATH="$VENDOR_PREFIX/lib64/pkgconfig:$VENDOR_PREFIX/lib/pkgconfig"
export PATH="$VENDOR_PREFIX/bin:$PATH"
make -C lua-%{lua_version} -j%{_smp_build_ncpus} linux \
  CC="%{__cc}" \
  MYCFLAGS="%{optflags} -fPIC" \
  MYLDFLAGS="%{build_ldflags}"
make -C lua-%{lua_version} install \
  INSTALL_TOP="$VENDOR_PREFIX" \
  INSTALL_LIB="$VENDOR_PREFIX/lib64"
mkdir -p "$VENDOR_PREFIX/lib64/pkgconfig"
printf '%s\n' \
  'prefix='"$VENDOR_PREFIX" \
  'exec_prefix=${prefix}' \
  'libdir=${prefix}/lib64' \
  'includedir=${prefix}/include' \
  '' \
  'Name: Lua' \
  'Description: Lua language engine' \
  'Version: %{lua_version}' \
  'Libs: -L${libdir} -llua -lm -ldl' \
  'Cflags: -I${includedir}' \
  > "$VENDOR_PREFIX/lib64/pkgconfig/lua%{lua_abi}.pc"
cmake -S hyprwayland-scanner-%{hyprwayland_scanner_version} -B hyprwayland-scanner-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib64
cmake --build hyprwayland-scanner-build --parallel %{_smp_build_ncpus}
cmake --install hyprwayland-scanner-build
cmake -S hyprutils-%{hyprutils_version} -B hyprutils-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib64 \
  -DCMAKE_INSTALL_RPATH='$ORIGIN' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
cmake --build hyprutils-build --parallel %{_smp_build_ncpus}
cmake --install hyprutils-build
cmake -S hyprwire-%{hyprwire_version} -B hyprwire-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib64 \
  -DCMAKE_INSTALL_RPATH='$ORIGIN' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
cmake --build hyprwire-build --parallel %{_smp_build_ncpus}
cmake --install hyprwire-build
cmake -S hyprlang-%{hyprlang_version} -B hyprlang-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib64 \
  -DCMAKE_INSTALL_RPATH='$ORIGIN' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
cmake --build hyprlang-build --parallel %{_smp_build_ncpus}
cmake --install hyprlang-build
cmake -S hyprcursor-%{hyprcursor_version} -B hyprcursor-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib64 \
  -DCMAKE_INSTALL_RPATH='$ORIGIN' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
cmake --build hyprcursor-build --parallel %{_smp_build_ncpus}
cmake --install hyprcursor-build
cmake -S hyprgraphics-%{hyprgraphics_version} -B hyprgraphics-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib64 \
  -DCMAKE_INSTALL_RPATH='$ORIGIN' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DOPENGL_opengl_LIBRARY=%{_libdir}/libOpenGL.so \
  -DOPENGL_gles3_LIBRARY=%{_libdir}/libGLESv2.so \
  -DOPENGL_GLES3_INCLUDE_DIR=%{_includedir} \
  -DOPENGL_egl_LIBRARY=%{_libdir}/libEGL.so \
  -DOPENGL_EGL_INCLUDE_DIR=%{_includedir} \
  -DOPENGL_INCLUDE_DIR=%{_includedir}
cmake --build hyprgraphics-build --parallel %{_smp_build_ncpus}
cmake --install hyprgraphics-build
cmake -S aquamarine-%{aquamarine_version} -B aquamarine-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib64 \
  -DCMAKE_INSTALL_RPATH='$ORIGIN' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DOPENGL_opengl_LIBRARY=%{_libdir}/libOpenGL.so \
  -DOPENGL_gles3_LIBRARY=%{_libdir}/libGLESv2.so \
  -DOPENGL_GLES3_INCLUDE_DIR=%{_includedir} \
  -DOPENGL_egl_LIBRARY=%{_libdir}/libEGL.so \
  -DOPENGL_EGL_INCLUDE_DIR=%{_includedir} \
  -DOPENGL_INCLUDE_DIR=%{_includedir}
cmake --build aquamarine-build --parallel %{_smp_build_ncpus}
cmake --install aquamarine-build
cmake -S hyprtoolkit-%{hyprtoolkit_version} -B hyprtoolkit-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib64 \
  -DCMAKE_INSTALL_RPATH='$ORIGIN' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DOPENGL_opengl_LIBRARY=%{_libdir}/libOpenGL.so \
  -DOPENGL_gles3_LIBRARY=%{_libdir}/libGLESv2.so \
  -DOPENGL_GLES3_INCLUDE_DIR=%{_includedir} \
  -DOPENGL_egl_LIBRARY=%{_libdir}/libEGL.so \
  -DOPENGL_EGL_INCLUDE_DIR=%{_includedir} \
  -DOPENGL_INCLUDE_DIR=%{_includedir}
cmake --build hyprtoolkit-build --parallel %{_smp_build_ncpus}
cmake --install hyprtoolkit-build
# Release archives do not contain .git; provide reproducible version metadata.
export GIT_TAG="v%{version}"
export GIT_BRANCH="main"
export GIT_COMMIT_HASH="%{hyprland_commit}"
export GIT_COMMIT_MESSAGE="Release v%{version}"
export GIT_COMMIT_DATE="$(date -u -d "@${SOURCE_DATE_EPOCH}" +%%Y-%%m-%%d)"
export GIT_DIRTY="clean"
export GIT_COMMITS="0"
%cmake -G Ninja \
  -DFETCHCONTENT_SOURCE_DIR_GLAZE="$PWD/glaze-%{glaze_version}" \
  -DCMAKE_INSTALL_RPATH='$ORIGIN/../libexec/hyprland/vendor/lib64:$ORIGIN/../libexec/hyprland/vendor/lib' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DOPENGL_opengl_LIBRARY=%{_libdir}/libOpenGL.so \
  -DOPENGL_gles3_LIBRARY=%{_libdir}/libGLESv2.so \
  -DOPENGL_GLES3_INCLUDE_DIR=%{_includedir} \
  -DOPENGL_egl_LIBRARY=%{_libdir}/libEGL.so \
  -DOPENGL_EGL_INCLUDE_DIR=%{_includedir} \
  -DOPENGL_INCLUDE_DIR=%{_includedir}
%cmake_build
cmake -S hyprland-guiutils-%{guiutils_version} -B guiutils-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=%{_prefix} \
  -DCMAKE_INSTALL_LIBDIR=%{_lib} \
  -DCMAKE_INSTALL_RPATH='$ORIGIN/../libexec/hyprland/vendor/lib64' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
cmake --build guiutils-build --parallel %{_smp_build_ncpus}
cmake -S xdg-desktop-portal-hyprland-%{portal_version} -B portal-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=%{_prefix} \
  -DCMAKE_INSTALL_LIBEXECDIR=%{_libexecdir} \
  -DCMAKE_INSTALL_RPATH='$ORIGIN/hyprland/vendor/lib64;$ORIGIN/../libexec/hyprland/vendor/lib64' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
cmake --build portal-build --parallel %{_smp_build_ncpus}

%check
test -x %{__cmake_builddir}/Hyprland
test -x %{__cmake_builddir}/hyprctl/hyprctl
test -x %{__cmake_builddir}/hyprpm/hyprpm
test -x %{__cmake_builddir}/start/start-hyprland
test -x guiutils-build/utils/dialog/hyprland-dialog
test -x guiutils-build/utils/donate-screen/hyprland-donate-screen
test -x guiutils-build/utils/update-screen/hyprland-update-screen
test -x guiutils-build/utils/welcome/hyprland-welcome
test -x guiutils-build/utils/run/hyprland-run
test -x portal-build/xdg-desktop-portal-hyprland
test -x portal-build/hyprland-share-picker/hyprland-share-picker

%install
%cmake_install
DESTDIR=%{buildroot} cmake --install guiutils-build
DESTDIR=%{buildroot} cmake --install portal-build
ln -sfn Hyprland %{buildroot}%{_bindir}/hyprland
ln -sfn Hyprland.1 %{buildroot}%{_mandir}/man1/hyprland.1
install -d %{buildroot}%{_libexecdir}/hyprland/vendor/lib64
cp -a vendor/lib64/lib*.so* %{buildroot}%{_libexecdir}/hyprland/vendor/lib64/

rm -rf %{buildroot}%{_includedir}/hyprland
rm -f %{buildroot}%{_datadir}/pkgconfig/hyprland.pc
rm -f %{buildroot}%{_libexecdir}/hyprland/vendor/lib64/lib*.so
rm -rf %{buildroot}%{_datadir}/bash-completion
rm -rf %{buildroot}%{_datadir}/fish/vendor_completions.d

%files
%license LICENSE
%doc README.md
%{_bindir}/Hyprland
%{_bindir}/hyprland
%{_bindir}/hyprctl
%{_bindir}/hyprpm
%{_bindir}/start-hyprland
%dir %{_libexecdir}/hyprland
%{_libexecdir}/hyprland/vendor/
%{_datadir}/hypr/
%{_datadir}/wayland-sessions/hyprland.desktop
%{_datadir}/wayland-sessions/hyprland-uwsm.desktop
%{_datadir}/xdg-desktop-portal/hyprland-portals.conf
%{_mandir}/man1/Hyprland.1*
%{_mandir}/man1/hyprland.1*
%{_mandir}/man1/hyprctl.1*
%{_datadir}/zsh/site-functions/_hyprctl
%{_datadir}/zsh/site-functions/_hyprpm

%files -n hyprland-guiutils
%{_bindir}/hyprland-dialog
%{_bindir}/hyprland-donate-screen
%{_bindir}/hyprland-update-screen
%{_bindir}/hyprland-welcome
%{_bindir}/hyprland-run

%files -n xdg-desktop-portal-hyprland
%{_bindir}/hyprland-share-picker
%{_libexecdir}/xdg-desktop-portal-hyprland
%{_datadir}/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service
%{_datadir}/xdg-desktop-portal/portals/hyprland.portal
%{_userunitdir}/xdg-desktop-portal-hyprland.service

%changelog
* Tue Oct 06 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.56.2-2
- Build xdg-desktop-portal-hyprland 1.4.1 as a subpackage

* Sun Oct 04 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.56.2-1
- Package Hyprland 0.56.2 for Fedora 44
- Build compatible tagged Hypr libraries in a private runtime prefix
- Enable Xwayland, Lua 5.5 configuration, hyprctl, hyprpm, and start-hyprland
