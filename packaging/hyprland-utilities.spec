Name:           hyprland-utilities
Version:        0.1
Release:        1%{?dist}
Summary:        Tagged Hyprland desktop utility collection

License:        BSD-3-Clause
URL:            https://hypr.land/

%global hypridle_version 0.1.8
%global hyprlock_version 0.9.6
%global hyprsunset_version 0.4.0
%global hyprpicker_version 0.4.7
%global hyprland_version 0.56.2
%global hyprland_release 2
%global hyprland_protocols_version 0.7.0
%global hyprwayland_scanner_version 0.4.6
%global hyprutils_version 0.14.2
%global hyprlang_version 0.6.8
%global hyprgraphics_version 0.5.1

Source0:        https://github.com/hyprwm/hypridle/archive/refs/tags/v%{hypridle_version}.tar.gz#/hypridle-%{hypridle_version}.tar.gz
Source1:        https://github.com/hyprwm/hyprlock/archive/refs/tags/v%{hyprlock_version}.tar.gz#/hyprlock-%{hyprlock_version}.tar.gz
Source2:        https://github.com/hyprwm/hyprsunset/archive/refs/tags/v%{hyprsunset_version}.tar.gz#/hyprsunset-%{hyprsunset_version}.tar.gz
Source3:        https://github.com/hyprwm/hyprpicker/archive/refs/tags/v%{hyprpicker_version}.tar.gz#/hyprpicker-%{hyprpicker_version}.tar.gz
Source10:       https://github.com/hyprwm/hyprland-protocols/archive/refs/tags/v%{hyprland_protocols_version}.tar.gz#/hyprland-protocols-%{hyprland_protocols_version}.tar.gz
Source11:       https://github.com/hyprwm/hyprwayland-scanner/archive/refs/tags/v%{hyprwayland_scanner_version}.tar.gz#/hyprwayland-scanner-%{hyprwayland_scanner_version}.tar.gz
Source12:       https://github.com/hyprwm/hyprutils/archive/refs/tags/v%{hyprutils_version}.tar.gz#/hyprutils-%{hyprutils_version}.tar.gz
Source13:       https://github.com/hyprwm/hyprlang/archive/refs/tags/v%{hyprlang_version}.tar.gz#/hyprlang-%{hyprlang_version}.tar.gz
Source14:       https://github.com/hyprwm/hyprgraphics/archive/refs/tags/v%{hyprgraphics_version}.tar.gz#/hyprgraphics-%{hyprgraphics_version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  ninja-build
BuildRequires:  pkgconfig
BuildRequires:  cairo-devel
BuildRequires:  file-devel
BuildRequires:  libdrm-devel
BuildRequires:  libglvnd-devel
BuildRequires:  libjpeg-turbo-devel
BuildRequires:  libwebp-devel
BuildRequires:  libxkbcommon-devel
BuildRequires:  librsvg2-devel
BuildRequires:  mesa-libgbm-devel
BuildRequires:  pam-devel
BuildRequires:  pango-devel
BuildRequires:  pixman-devel
BuildRequires:  pugixml-devel
BuildRequires:  sdbus-cpp-devel >= 2.0.0
BuildRequires:  systemd-rpm-macros
BuildRequires:  wayland-devel
BuildRequires:  wayland-protocols-devel

Requires:       hypridle%{?_isa} = %{hypridle_version}-%{release}
Requires:       hyprlock%{?_isa} = %{hyprlock_version}-%{release}
Requires:       hyprsunset%{?_isa} = %{hyprsunset_version}-%{release}
Requires:       hyprpicker%{?_isa} = %{hyprpicker_version}-%{release}

%description
Meta-package for the tagged Hyprland idle daemon, lock screen, blue-light
filter, and color picker used by My Distro.

%package -n hypridle
Version:        %{hypridle_version}
Summary:        Hyprland idle daemon
Requires:       hyprland%{?_isa} = %{hyprland_version}-%{hyprland_release}%{?dist}

%description -n hypridle
Hyprland's idle management daemon with timeout and resume hooks.

%package -n hyprlock
Version:        %{hyprlock_version}
Summary:        Hyprland lock screen
Requires:       hyprland%{?_isa} = %{hyprland_version}-%{hyprland_release}%{?dist}

%description -n hyprlock
GPU-accelerated session lock screen for Hyprland and other Wayland compositors.

%package -n hyprsunset
Version:        %{hyprsunset_version}
Summary:        Blue-light filter for Hyprland
Requires:       hyprland%{?_isa} = %{hyprland_version}-%{hyprland_release}%{?dist}

%description -n hyprsunset
Hyprland blue-light filter with scheduled color-temperature profiles.

%package -n hyprpicker
Version:        %{hyprpicker_version}
Summary:        Wayland color picker for Hyprland
Requires:       hyprland%{?_isa} = %{hyprland_version}-%{hyprland_release}%{?dist}

%description -n hyprpicker
Native Wayland color picker using the compositor screencopy protocols.

%prep
%setup -q -c -T
tar -xzf %{SOURCE0}
tar -xzf %{SOURCE1}
tar -xzf %{SOURCE2}
tar -xzf %{SOURCE3}
tar -xzf %{SOURCE10}
tar -xzf %{SOURCE11}
tar -xzf %{SOURCE12}
tar -xzf %{SOURCE13}
tar -xzf %{SOURCE14}

%build
VENDOR_PREFIX="$PWD/vendor"
mkdir -p "$VENDOR_PREFIX/lib64/pkgconfig" "$VENDOR_PREFIX/share/hyprland-protocols"
export CMAKE_PREFIX_PATH="$VENDOR_PREFIX"
export PKG_CONFIG_PATH="$VENDOR_PREFIX/lib64/pkgconfig:$VENDOR_PREFIX/lib/pkgconfig"
export PATH="$VENDOR_PREFIX/bin:$PATH"

cp -a hyprland-protocols-%{hyprland_protocols_version}/protocols \
    "$VENDOR_PREFIX/share/hyprland-protocols/"
cat >"$VENDOR_PREFIX/lib64/pkgconfig/hyprland-protocols.pc" <<EOF
prefix=$VENDOR_PREFIX
datadir=\${prefix}/share
pkgdatadir=\${datadir}/hyprland-protocols

Name: hyprland-protocols
Description: Wayland protocol extensions for Hyprland
Version: %{hyprland_protocols_version}
EOF

cmake -S hyprwayland-scanner-%{hyprwayland_scanner_version} -B scanner-build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
    -DCMAKE_INSTALL_LIBDIR=lib64
cmake --build scanner-build --parallel %{_smp_build_ncpus}
cmake --install scanner-build

cmake -S hyprutils-%{hyprutils_version} -B utils-build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
    -DCMAKE_INSTALL_LIBDIR=lib64
cmake --build utils-build --parallel %{_smp_build_ncpus}
cmake --install utils-build

cmake -S hyprlang-%{hyprlang_version} -B lang-build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
    -DCMAKE_INSTALL_LIBDIR=lib64
cmake --build lang-build --parallel %{_smp_build_ncpus}
cmake --install lang-build

cmake -S hyprgraphics-%{hyprgraphics_version} -B graphics-build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$VENDOR_PREFIX" \
    -DCMAKE_INSTALL_LIBDIR=lib64 \
    -DOPENGL_opengl_LIBRARY=%{_libdir}/libOpenGL.so \
    -DOPENGL_gles3_LIBRARY=%{_libdir}/libGLESv2.so \
    -DOPENGL_GLES3_INCLUDE_DIR=%{_includedir} \
    -DOPENGL_egl_LIBRARY=%{_libdir}/libEGL.so \
    -DOPENGL_EGL_INCLUDE_DIR=%{_includedir} \
    -DOPENGL_INCLUDE_DIR=%{_includedir}
cmake --build graphics-build --parallel %{_smp_build_ncpus}
cmake --install graphics-build

COMMON_ARGS="-G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=%{_prefix} -DCMAKE_INSTALL_LIBDIR=%{_lib} -DCMAKE_INSTALL_RPATH=/usr/libexec/hyprland/vendor/lib64 -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"

cmake -S hypridle-%{hypridle_version} -B hypridle-build $COMMON_ARGS
cmake --build hypridle-build --parallel %{_smp_build_ncpus}

cmake -S hyprlock-%{hyprlock_version} -B hyprlock-build $COMMON_ARGS \
    -DHYPRLOCK_COMMIT=b222d9b -DHYPRLOCK_VERSION_COMMIT=b222d9b \
    -DOPENGL_opengl_LIBRARY=%{_libdir}/libOpenGL.so \
    -DOPENGL_gles3_LIBRARY=%{_libdir}/libGLESv2.so \
    -DOPENGL_GLES3_INCLUDE_DIR=%{_includedir} \
    -DOPENGL_egl_LIBRARY=%{_libdir}/libEGL.so \
    -DOPENGL_EGL_INCLUDE_DIR=%{_includedir} \
    -DOPENGL_INCLUDE_DIR=%{_includedir}
cmake --build hyprlock-build --parallel %{_smp_build_ncpus}

cmake -S hyprsunset-%{hyprsunset_version} -B hyprsunset-build $COMMON_ARGS
cmake --build hyprsunset-build --parallel %{_smp_build_ncpus}

cmake -S hyprpicker-%{hyprpicker_version} -B hyprpicker-build $COMMON_ARGS
cmake --build hyprpicker-build --parallel %{_smp_build_ncpus}

%install
DESTDIR=%{buildroot} cmake --install hypridle-build
DESTDIR=%{buildroot} cmake --install hyprlock-build
DESTDIR=%{buildroot} cmake --install hyprsunset-build
DESTDIR=%{buildroot} cmake --install hyprpicker-build

%files

%files -n hypridle
%license hypridle-%{hypridle_version}/LICENSE
%{_bindir}/hypridle
%{_userunitdir}/hypridle.service
%{_datadir}/hypr/hypridle.conf

%files -n hyprlock
%license hyprlock-%{hyprlock_version}/LICENSE
%{_bindir}/hyprlock
%config(noreplace) %{_sysconfdir}/pam.d/hyprlock
%{_datadir}/hypr/hyprlock.conf

%files -n hyprsunset
%license hyprsunset-%{hyprsunset_version}/LICENSE
%{_bindir}/hyprsunset
%{_userunitdir}/hyprsunset.service

%files -n hyprpicker
%license hyprpicker-%{hyprpicker_version}/LICENSE
%{_bindir}/hyprpicker
%{_mandir}/man1/hyprpicker.1*

%changelog
* Wed Oct 07 2026 Liam <liam@localhost> - 0.1-1
- Package hypridle 0.1.8, hyprlock 0.9.6, hyprsunset 0.4.0, and hyprpicker 0.4.7
- Build only from upstream release tags compatible with Hyprland 0.56.2
