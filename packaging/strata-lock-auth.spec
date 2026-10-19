Name:           strata-lock-auth
Version:        0.1
Release:        2%{?dist}
Summary:        Fedora PAM configuration for the Strata lock screen
License:        MIT
URL:            https://github.com/name-is-hai/strata
Source0:        strata-lock-password
Source1:        hyprland-desktop-LICENSE
BuildArch:      noarch
Requires:       pam

%description
Password authentication policy for the Strata lock screen, using Fedora's
maintained login PAM stack.

%prep
%setup -q -c -T
cp -p %{SOURCE1} LICENSE

%build
# No compilation is required.

%install
install -Dpm 0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/pam.d/strata-lock-password

%files
%license LICENSE
%config(noreplace) %{_sysconfdir}/pam.d/strata-lock-password

%changelog
* Mon Oct 19 2026 Strata Maintainers <maintainers@strata.dev> - 0.1-2
- Build the lock authentication policy from source in release CI
