//! Fedora firewalld zone and temporary rules. No user-supplied command is executed.
use anyhow::{bail, Context, Result};
use std::{net::Ipv4Addr, process::Stdio, time::Duration};
use tokio::{io::AsyncWriteExt, process::Command};

/// Dedicated chain installed by the root-owned installer in UFW before.rules.
pub const CHAIN: &str = "waycast-input";
// Reserved network-device group, paired with the exact interface name. A new
// interface reusing that name starts in group 0 and cannot inherit these rules.
const DEVICE_GROUP: u32 = 0x574644;

/// Validated interface identity; a name alone is not sufficient authorization.
#[derive(Debug, Clone)]
pub struct GroupInterface {
    /// Kernel interface name.
    pub name: String,
    /// Kernel interface index, checked before every firewall update.
    pub index: u32,
    phy: std::path::PathBuf,
}

impl GroupInterface {
    /// Resolve an interface from a trusted supplicant event and ensure it belongs
    /// to the radio selected through NetworkManager.
    pub fn validate(radio: &str, name: &str) -> Result<Self> {
        validate_name(radio)?;
        validate_name(name)?;
        if !(name.starts_with("p2p-") || name == "p2p0") {
            bail!("Not a P2P data interface");
        }
        let phy = std::fs::canonicalize(format!("/sys/class/net/{radio}/phy80211"))?;
        let result = Self {
            name: name.into(),
            index: interface_index(name)?,
            phy,
        };
        if !result.identity_matches() {
            bail!("P2P interface is not on the selected radio");
        }
        Ok(result)
    }

    /// Tag this helper-owned interface so name reuse cannot inherit allowances.
    pub async fn claim(&self) -> Result<()> {
        if !self.identity_matches() {
            bail!("P2P interface was replaced before setup");
        }
        let group = device_group(&self.name)?;
        if group != 0 && group != DEVICE_GROUP {
            bail!("P2P interface already has a custom device group");
        }
        run(
            "/usr/bin/ip",
            &[
                "link",
                "set",
                "dev",
                &self.name,
                "group",
                &DEVICE_GROUP.to_string(),
            ],
            None,
        )
        .await?;
        if !self.exists() {
            bail!("P2P interface changed while tagging it");
        }
        Ok(())
    }

    /// Detect deletion/replacement before reusing an interface-scoped allowance.
    pub fn exists(&self) -> bool {
        self.identity_matches() && device_group(&self.name).ok() == Some(DEVICE_GROUP)
    }

    fn identity_matches(&self) -> bool {
        interface_index(&self.name).ok() == Some(self.index)
            && std::fs::canonicalize(format!("/sys/class/net/{}/phy80211", self.name))
                .ok()
                .as_ref()
                == Some(&self.phy)
    }
}

/// Restrict strings interpolated into iptables-restore to kernel interface names.
pub fn validate_name(name: &str) -> Result<()> {
    if name.is_empty()
        || name.len() > 15
        || !name
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || b"_-".contains(&c))
    {
        bail!("Invalid network interface name");
    }
    Ok(())
}

fn device_group(name: &str) -> Result<u32> {
    Ok(
        std::fs::read_to_string(format!("/sys/class/net/{name}/netdev_group"))?
            .trim()
            .parse()?,
    )
}

fn interface_index(name: &str) -> Result<u32> {
    Ok(
        std::fs::read_to_string(format!("/sys/class/net/{name}/ifindex"))?
            .trim()
            .parse()?,
    )
}

/// Complete desired rules for the single supported casting session.
#[derive(Debug, Clone)]
pub struct Rules {
    /// Interface validated from the selected radio's group-start signal.
    pub interface: GroupInterface,
    /// Whether the source serves DHCP.
    pub group_owner: bool,
    /// Source RTSP listening port, matching its WFD advertisement.
    pub rtsp: u16,
    /// Local IPv4 after address configuration.
    pub local: Option<Ipv4Addr>,
    /// Peer learned from the connected control socket.
    pub peer: Option<Ipv4Addr>,
    /// (Local port, remote port) for RTCP; absent if sink didn't negotiate RTCP.
    pub rtcp: Option<(u16, u16)>,
}

impl Rules {
    /// Render only this session's allowances. All other traffic returns to UFW.
    pub fn lines(&self) -> Result<Vec<String>> {
        validate_name(&self.interface.name)?;
        if self.rtsp < 1024 {
            bail!("Refusing a privileged RTSP port");
        }
        let prefix = format!(
            "-A {CHAIN} -i {} -m devgroup --src-group 0x{DEVICE_GROUP:x}",
            self.interface.name
        );
        let mut rules = vec![format!("{prefix} -p udp --sport 67 --dport 68 -j ACCEPT")];
        if self.group_owner {
            // A DHCPDISCOVER has no leased source address yet.
            rules.push(format!("{prefix} -p udp --sport 68 --dport 67 -j ACCEPT"));
        }
        let local = self
            .local
            .map(|ip| format!(" -d {ip}/32"))
            .unwrap_or_default();
        let peer = self
            .peer
            .map(|ip| format!(" -s {ip}/32"))
            .unwrap_or_default();
        rules.push(format!(
            "{prefix}{local}{peer} -p tcp --dport {} -j ACCEPT",
            self.rtsp
        ));
        if let Some((local_port, remote_port)) = self.rtcp {
            if self.local.is_none() || self.peer.is_none() || local_port < 1024 || remote_port == 0
            {
                bail!("RTCP requires validated local/peer addresses and ports");
            }
            rules.push(format!(
                "{prefix}{local}{peer} -p udp --sport {remote_port} --dport {local_port} -j ACCEPT"
            ));
        }
        Ok(rules)
    }

    /// Firewalld owns the input path on Fedora. Keep allowances in a dedicated
    /// zone attached only to the validated, helper-owned Wi-Fi Direct interface.
    pub fn rich_rules(&self) -> Result<Vec<String>> {
        self.lines()?; // shared address/port validation
        let prefix = "rule family=\"ipv4\"";
        let mut rules = vec![format!("{prefix} port port=\"68\" protocol=\"udp\" accept")];
        if self.group_owner { rules.push(format!("{prefix} port port=\"67\" protocol=\"udp\" accept")); }
        let source = self.peer.map(|ip| format!(" source address=\"{ip}/32\"")).unwrap_or_default();
        let destination = self.local.map(|ip| format!(" destination address=\"{ip}/32\"")).unwrap_or_default();
        rules.push(format!("{prefix}{source}{destination} port port=\"{}\" protocol=\"tcp\" accept", self.rtsp));
        if let Some((port, _)) = self.rtcp {
            rules.push(format!("{prefix}{source}{destination} port port=\"{port}\" protocol=\"udp\" accept"));
        }
        Ok(rules)
    }

    pub async fn apply(&self) -> Result<()> {
        if !self.interface.exists() { bail!("P2P interface disappeared or was replaced"); }
        ensure_hook().await?;
        let wanted = self.rich_rules()?;
        let current = firewalld(&["--list-rich-rules"]).await?;
        for old in current.lines().filter(|line| !line.is_empty()) {
            if !wanted.iter().any(|rule| rule == old) {
                firewalld(&[&format!("--remove-rich-rule={old}")]).await?;
            }
        }
        for rule in &wanted {
            if !current.lines().any(|line| line == rule) {
                firewalld(&[&format!("--add-rich-rule={rule}")]).await?;
            }
        }
        firewalld(&[&format!("--change-interface={}", self.interface.name)]).await?;
        Ok(())
    }

    pub async fn intact(&self) -> bool {
        if !self.interface.exists() { return false; }
        let Ok(interfaces) = firewalld(&["--list-interfaces"]).await else { return false; };
        if !interfaces.split_whitespace().any(|name| name == self.interface.name) { return false; }
        let Ok(actual) = firewalld(&["--list-rich-rules"]).await else { return false; };
        let Ok(expected) = self.rich_rules() else { return false; };
        let mut actual: Vec<_> = actual.lines().filter(|line| !line.is_empty()).map(str::to_owned).collect();
        let mut expected = expected;
        actual.sort(); expected.sort(); actual == expected
    }
}


pub(crate) async fn run(binary: &str, args: &[&str], input: Option<&str>) -> Result<String> {
    let mut command = Command::new(binary);
    command
        .args(args)
        .env_clear()
        .env("PATH", "/usr/bin:/usr/sbin")
        .env("LC_ALL", "C")
        .kill_on_drop(true)
        .stdin(if input.is_some() {
            Stdio::piped()
        } else {
            Stdio::null()
        })
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    #[cfg(test)]
    if let Ok(parent) = std::env::var("WAYCAST_PARENT_NETNS") {
        command.env("WAYCAST_PARENT_NETNS", parent);
    }
    let mut child = command
        .spawn()
        .with_context(|| format!("Starting {binary}"))?;
    let result = tokio::time::timeout(Duration::from_secs(8), async {
        if let Some(input) = input {
            child
                .stdin
                .take()
                .context("Missing command stdin")?
                .write_all(input.as_bytes())
                .await?;
        }
        let output = child.wait_with_output().await?;
        if !output.status.success() {
            bail!(
                "{binary}: {}",
                String::from_utf8_lossy(&output.stderr).trim()
            );
        }
        Ok(String::from_utf8_lossy(&output.stdout).into_owned())
    })
    .await
    .context("Firewall command timed out")?;
    result
}

async fn firewalld(args: &[&str]) -> Result<String> {
    let mut all = vec!["--zone=strata-wireless"];
    all.extend_from_slice(args);
    run("/usr/bin/firewall-cmd", &all, None).await
}

pub async fn ensure_hook() -> Result<()> {
    firewalld(&["--get-target"]).await.context("Strata wireless firewalld zone is unavailable")?;
    Ok(())
}

pub async fn cleanup() -> Result<()> {
    // A stopped/reloading firewall has no runtime allowances to remove.
    let Ok(rules) = firewalld(&["--list-rich-rules"]).await else { return Ok(()); };
    for rule in rules.lines().filter(|line| !line.is_empty()) {
        firewalld(&[&format!("--remove-rich-rule={rule}")]).await?;
    }
    let interfaces = firewalld(&["--list-interfaces"]).await?;
    for interface in interfaces.split_whitespace() {
        validate_name(interface)?;
        firewalld(&[&format!("--remove-interface={interface}")]).await?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn rules(owner: bool) -> Rules {
        Rules {
            interface: GroupInterface {
                name: "p2p-wlan0-0".into(),
                index: 10,
                phy: "/fake".into(),
            },
            group_owner: owner,
            rtsp: 7236,
            local: None,
            peer: None,
            rtcp: None,
        }
    }
    #[test]
    fn dhcp_bootstrap_is_role_scoped_without_requiring_a_lease() {
        assert_eq!(rules(false).lines().unwrap().len(), 2);
        let lines = rules(true).lines().unwrap();
        assert!(lines
            .iter()
            .any(|line| line.contains("--sport 68 --dport 67")));
        assert!(lines.iter().all(|line| line.contains("-i p2p-wlan0-0")));
        assert!(!lines.iter().any(|line| line.contains(" -s ")));
    }
    #[test]
    fn media_rules_are_exact_and_do_not_open_fixed_5005() {
        let mut r = rules(false);
        r.local = Some("192.168.49.10".parse().unwrap());
        r.peer = Some("192.168.49.1".parse().unwrap());
        r.rtcp = Some((45001, 19007));
        assert!(r
            .lines()
            .unwrap()
            .last()
            .unwrap()
            .contains("-d 192.168.49.10/32 -s 192.168.49.1/32 -p udp --sport 19007 --dport 45001"));
    }
    #[test]
    fn rejects_injection_and_unvalidated_media() {
        for name in ["", "p2p+", "eth0\n-F INPUT", "../../etc", "-i eth0"] {
            assert!(validate_name(name).is_err());
        }
        let mut r = rules(false);
        r.rtcp = Some((45001, 5005));
        assert!(r.lines().is_err());
        r.rtcp = None;
        r.rtsp = 22;
        assert!(r.lines().is_err());
    }
    #[test]
    fn firewalld_rules_scope_media_to_the_negotiated_peer_and_listener() {
        let mut r = rules(false);
        r.local = Some("192.168.49.10".parse().unwrap());
        r.peer = Some("192.168.49.1".parse().unwrap());
        r.rtcp = Some((45001, 19007));
        let rich = r.rich_rules().unwrap();
        assert_eq!(rich.len(), 3);
        for rule in &rich[1..] {
            assert!(rule.contains("source address=\"192.168.49.1/32\""));
            assert!(rule.contains("destination address=\"192.168.49.10/32\""));
        }
        assert!(rich[2].contains("port=\"45001\""));
        assert!(!rich.iter().any(|rule| rule.contains("5005")));
        assert_eq!(rules(true).rich_rules().unwrap().len(), 3);
    }
}
