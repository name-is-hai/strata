Strata adaptation of liberuum/unicast, revision recorded in UPSTREAM.

Changes: Strata command/config/runtime names; use the RPM-owned user service
on demand; Fedora firewalld instead of UFW; remove owned runtime allowances
on session teardown. The upstream protocol, discovery, pinned-descriptor media
server, subtitles, receiver controls and transcoding are retained.

Build: cargo build --release --locked. Protocol tests: cargo test --locked.
The complete installed package is defined by packaging/strata-casting.spec.

Media firewall ownership lives in strata-waycast-networkd. Each session holds a
dedicated system-bus connection; caller loss triggers root-side cleanup. The
helper journals the exact allowance before insertion, retries failed removals,
and recovers the journal through systemd ExecStopPost and startup cleanup.
