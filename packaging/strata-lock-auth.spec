Name:           strata-lock-auth
Version:        0.1
Release:        3%{?dist}
Summary:        Fedora PAM configuration for the Strata lock screen
License:        MIT
URL:            https://github.com/name-is-hai/strata
Source0:        strata-lock-password
Source1:        hyprland-desktop-LICENSE
Source2:        strata-lock-fingerprint
Source3:        strata-greetd
BuildArch:      noarch
Requires:       pam
Requires:       fprintd
Requires:       fprintd-pam

%description
Separate password and fingerprint authentication policies for the Strata lock
screen. Password unlock uses Fedora's maintained login PAM stack. Fingerprint
unlock becomes available after the user enrolls a supported reader with fprintd.
The Strata greeter policy tries fingerprint authentication before falling back
to Fedora's greetd policy; the greeter process itself uses greetd-greeter.

%prep
%setup -q -c -T
cp -p %{SOURCE1} LICENSE

%build
# No compilation is required.

%install
install -Dpm 0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/pam.d/strata-lock-password
install -Dpm 0644 %{SOURCE2} %{buildroot}%{_sysconfdir}/pam.d/strata-lock-fingerprint
install -Dpm 0644 %{SOURCE3} %{buildroot}%{_sysconfdir}/pam.d/strata-greetd

%files
%license LICENSE
%config(noreplace) %{_sysconfdir}/pam.d/strata-lock-password
%config(noreplace) %{_sysconfdir}/pam.d/strata-lock-fingerprint
%config(noreplace) %{_sysconfdir}/pam.d/strata-greetd

%changelog
* Sat Oct 31 2026 Strata Maintainers <maintainers@strata.dev> - 0.1-3
- Ship separate fingerprint unlock PAM policy and install fprintd with its PAM module by default
- Add a fingerprint-first greeter policy with bounded scan time and Fedora password fallback

* Mon Oct 19 2026 Strata Maintainers <maintainers@strata.dev> - 0.1-2
- Build the lock authentication policy from source in release CI
