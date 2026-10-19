//! Root-owned media allowance journal. Written before opening the port so even
//! a SIGKILL between firewall changes and bookkeeping is recoverable.
use anyhow::{Context, Result, bail};
use std::{net::Ipv4Addr, path::Path};

const JOURNAL: &str = "/run/strata-casting-firewall/media-rule";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Allowance {
    pub zone: String,
    pub receiver: Ipv4Addr,
    pub bind: Ipv4Addr,
    pub port: u16,
}

fn lan(ip: Ipv4Addr) -> bool {
    ip.is_private() || ip.is_link_local()
}

impl Allowance {
    pub fn validate(&self) -> Result<()> {
        if self.zone.is_empty()
            || self.zone.len() > 64
            || !self
                .zone
                .bytes()
                .all(|c| c.is_ascii_alphanumeric() || b"_-".contains(&c))
            || !lan(self.receiver)
            || !lan(self.bind)
            || self.receiver == self.bind
            || self.port < 1024
        {
            bail!("Invalid media firewall allowance");
        }
        Ok(())
    }

    pub fn rule(&self) -> String {
        format!(
            "rule family=\"ipv4\" source address=\"{}/32\" destination address=\"{}/32\" port port=\"{}\" protocol=\"tcp\" accept",
            self.receiver, self.bind, self.port
        )
    }

    fn encode(&self) -> String {
        format!(
            "{} {} {} {}\n",
            self.zone, self.receiver, self.bind, self.port
        )
    }

    fn decode(text: &str) -> Result<Self> {
        let fields: Vec<_> = text.split_whitespace().collect();
        if fields.len() != 4 {
            bail!("Invalid firewall journal");
        }
        let rule = Self {
            zone: fields[0].into(),
            receiver: fields[1].parse()?,
            bind: fields[2].parse()?,
            port: fields[3].parse()?,
        };
        rule.validate()?;
        Ok(rule)
    }
}

async fn command(args: &[&str]) -> Result<String> {
    super::firewall::run("/usr/bin/firewall-cmd", args, None).await
}

pub async fn prepare(receiver: &str, bind: &str, port: u16) -> Result<Allowance> {
    let receiver: Ipv4Addr = receiver.parse()?;
    let bind: Ipv4Addr = bind.parse()?;
    let mut rule = Allowance {
        zone: "public".into(),
        receiver,
        bind,
        port,
    };
    rule.validate()?;
    // Derive the destination interface and local address independently; a caller
    // cannot ask us to open an unrelated local interface or Internet endpoint.
    let route = super::firewall::run(
        "/usr/bin/ip",
        &["-o", "-4", "route", "get", &receiver.to_string()],
        None,
    )
    .await?;
    let fields: Vec<_> = route.split_whitespace().collect();
    let value = |key| fields.windows(2).find(|f| f[0] == key).map(|f| f[1]);
    if value("src") != Some(bind.to_string().as_str()) {
        bail!("Media listener does not match the receiver route");
    }
    let interface = value("dev").context("Receiver has no network interface")?;
    super::firewall::validate_name(interface)?;
    let source_zone = command(&[&format!("--get-zone-of-source={receiver}")])
        .await
        .ok();
    let interface_zone = command(&[&format!("--get-zone-of-interface={interface}")])
        .await
        .ok();
    let assigned = |s: &String| !s.trim().is_empty() && s.trim() != "no zone";
    rule.zone = match source_zone
        .filter(assigned)
        .or(interface_zone.filter(assigned))
    {
        Some(zone) => zone.trim().into(),
        None => command(&["--get-default-zone"]).await?.trim().into(),
    };
    rule.validate()?;
    Ok(rule)
}

pub async fn open(rule: &Allowance) -> Result<()> {
    rule.validate()?;
    let zone = format!("--zone={}", rule.zone);
    let rich = rule.rule();
    if command(&[&zone, &format!("--query-rich-rule={rich}")])
        .await
        .is_ok()
    {
        bail!("This media allowance already exists; refusing to take ownership of another rule");
    }
    let path = Path::new(JOURNAL);
    std::fs::create_dir_all(path.parent().unwrap())?;
    std::fs::write(path.with_extension("new"), rule.encode())?;
    std::fs::rename(path.with_extension("new"), path)?;
    command(&[&zone, &format!("--add-rich-rule={rich}")]).await?;
    Ok(())
}

pub async fn cleanup() -> Result<()> {
    cleanup_at(Path::new(JOURNAL)).await
}

async fn cleanup_at(path: &Path) -> Result<()> {
    let text = match std::fs::read_to_string(path) {
        Ok(text) => text,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(()),
        Err(error) => return Err(error.into()),
    };
    let rule = Allowance::decode(&text)?;
    let zone = format!("--zone={}", rule.zone);
    let rich = rule.rule();
    // Removal is idempotent. A reload may already have removed the rule. Verify
    // absence after the command; retain the journal on any uncertain outcome.
    let _ = command(&[&zone, &format!("--remove-rich-rule={rich}")]).await;
    let query = tokio::time::timeout(
        std::time::Duration::from_secs(8),
        tokio::process::Command::new("/usr/bin/firewall-cmd")
            .args([&zone, &format!("--query-rich-rule={rich}")])
            .kill_on_drop(true)
            .output(),
    )
    .await??;
    let absent = match query.status.code() {
        Some(1) => Ok(true), // firewalld's explicit "no"; absence is confirmed.
        Some(0) => Ok(false),
        _ => Err(anyhow::anyhow!(
            "Cannot verify firewall cleanup: {}",
            String::from_utf8_lossy(&query.stderr)
        )),
    };
    finish_cleanup(path, absent)
}

fn finish_cleanup(path: &Path, confirmed_absent: Result<bool>) -> Result<()> {
    if !confirmed_absent? {
        bail!("Temporary media firewall rule still exists; cleanup will retry");
    }
    match std::fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.into()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn failed_or_uncertain_removal_retains_recovery_journal() {
        let dir =
            std::env::temp_dir().join(format!("strata-firewall-journal-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("rule");
        std::fs::write(&path, "public 192.168.1.20 192.168.1.2 60020\n").unwrap();
        assert!(finish_cleanup(&path, Err(anyhow::anyhow!("firewalld unavailable"))).is_err());
        assert!(path.exists());
        assert!(finish_cleanup(&path, Ok(false)).is_err());
        assert!(path.exists());
        finish_cleanup(&path, Ok(true)).unwrap();
        assert!(!path.exists());
        finish_cleanup(&path, Ok(true)).unwrap(); // repeated recovery is harmless
        std::fs::remove_dir(&dir).unwrap();
    }

    #[test]
    fn journal_roundtrip_and_scope() {
        let rule = Allowance {
            zone: "FedoraWorkstation".into(),
            receiver: "192.168.1.20".parse().unwrap(),
            bind: "192.168.1.2".parse().unwrap(),
            port: 9871,
        };
        assert_eq!(Allowance::decode(&rule.encode()).unwrap(), rule);
        assert!(rule.rule().contains("192.168.1.20/32"));
        assert!(rule.rule().contains("192.168.1.2/32"));
        for invalid in [
            "public 8.8.8.8 192.168.1.2 9871",
            "public 192.168.1.20 0.0.0.0 9871",
            "public 192.168.1.20 192.168.1.2 22",
            "public 192.168.1.20 192.168.1.2 9871 extra",
            "../bad 192.168.1.20 192.168.1.2 9871",
        ] {
            assert!(Allowance::decode(invalid).is_err(), "{invalid}");
        }
    }
}
