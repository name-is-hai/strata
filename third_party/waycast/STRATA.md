Strata's Fedora adapter for alchemy/waycast, revision recorded in UPSTREAM.

Only the network helper is built here. Its firewall.rs uses a dedicated
firewalld zone on the validated P2P interface, with session-specific DHCP,
RTSP and RTCP destination ports, and verifies/removes its runtime rules.
The sender comes from the checksum-verified v0.6.1 release in the RPM spec.
Upstream UFW installers under contrib are reference material and are never run.

Build/test: cargo build --release --locked -p waycast-networkd;
cargo test --locked -p waycast-networkd --lib.
