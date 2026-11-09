Name:           strata-lock-auth
Version:        0.1
Release:        4%{?dist}
Summary:        Fedora authentication policies and Polkit method switching for Strata
License:        MIT
URL:            https://github.com/name-is-hai/strata
Source0:        strata-lock-password
Source1:        hyprland-desktop-LICENSE
Source2:        strata-lock-fingerprint
Source3:        strata-greetd
Source4:        pam_strata_polkit.c
Source5:        strata-polkit-use-password.c
Source6:        strata-polkit
Source7:        polkit-password-switch-test.c
BuildRequires:  gcc
BuildRequires:  pam-devel
Requires:       pam
Requires:       fprintd
Requires:       fprintd-pam >= 1.94.5

%description
Separate password and fingerprint authentication policies for the Strata lock
screen. Password unlock uses Fedora's maintained login PAM stack. Fingerprint
unlock becomes available after the user enrolls a supported reader with fprintd.
The Strata greeter policy tries fingerprint authentication before falling back
to Fedora's greetd policy; the greeter process itself uses greetd-greeter.
Polkit keeps Fedora's system-auth policy and supports interrupting an active
fingerprint scan to continue with a password in the same authorization request.

%prep
%setup -q -c -T
cp -p %{SOURCE1} LICENSE

%build
%{__cc} %{optflags} -fPIC -shared -Wl,-z,relro,-z,now -o pam_strata_polkit.so %{SOURCE4} -lpam -pthread
%{__cc} %{optflags} %{build_ldflags} -o strata-polkit-use-password %{SOURCE5}

%install
install -Dpm 0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/pam.d/strata-lock-password
install -Dpm 0644 %{SOURCE2} %{buildroot}%{_sysconfdir}/pam.d/strata-lock-fingerprint
install -Dpm 0644 %{SOURCE3} %{buildroot}%{_sysconfdir}/pam.d/strata-greetd
install -Dpm 0755 pam_strata_polkit.so %{buildroot}%{_libdir}/security/pam_strata_polkit.so
install -Dpm 0755 strata-polkit-use-password %{buildroot}%{_datadir}/strata/bin/strata-polkit-use-password
install -Dpm 0644 %{SOURCE6} %{buildroot}%{_sysconfdir}/pam.d/polkit-1

%check
mkdir -p test-pam
testdir=$(pwd)/test-pam
%{__cc} %{optflags} -fPIC -shared -DTEST_PAM_MODULE %{SOURCE7} -lpam -o "$testdir/test-pam.so"
%{__cc} %{optflags} %{SOURCE7} -lpam -o "$testdir/polkit-agent-helper-1"
%{__cc} %{optflags} -DSTRATA_POLKIT_HELPER="\"$testdir/polkit-agent-helper-1\"" %{SOURCE5} -o "$testdir/switch"
printf 'auth optional %s/pam_strata_polkit.so\nauth sufficient %s/test-pam.so fingerprint\nauth required %s/test-pam.so password\n' \
    "$(pwd)" "$testdir" "$testdir" > "$testdir/polkit-1"
"$testdir/polkit-agent-helper-1" "$testdir/polkit-agent-helper-1" "$testdir" "$testdir/switch"

%files
%license LICENSE
%config(noreplace) %{_sysconfdir}/pam.d/strata-lock-password
%config(noreplace) %{_sysconfdir}/pam.d/strata-lock-fingerprint
%config(noreplace) %{_sysconfdir}/pam.d/strata-greetd
%config(noreplace) %{_sysconfdir}/pam.d/polkit-1
%{_libdir}/security/pam_strata_polkit.so
%{_datadir}/strata/bin/strata-polkit-use-password

%changelog
* Mon Nov 09 2026 Strata Maintainers <maintainers@strata.dev> - 0.1-4
- Allow Polkit fingerprint scans to fall through immediately to password authentication

* Sat Oct 31 2026 Strata Maintainers <maintainers@strata.dev> - 0.1-3
- Ship separate fingerprint unlock PAM policy and install fprintd with its PAM module by default
- Add a fingerprint-first greeter policy with bounded scan time and Fedora password fallback

* Mon Oct 19 2026 Strata Maintainers <maintainers@strata.dev> - 0.1-2
- Build the lock authentication policy from source in release CI
