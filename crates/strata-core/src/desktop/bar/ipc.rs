use anyhow::{bail, Context, Result};
use std::process::Command;

/// Compatibility bridge: let the existing Strata shell helper handle socket and qs IPC.
pub fn call(method: &str, args: &[&str]) -> Result<String> {
    let output = Command::new("strata-shell")
        .args(["shell", method])
        .args(args)
        .output()
        .with_context(|| format!("could not run strata-shell shell {method}"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);
        bail!("{}", if stderr.trim().is_empty() { stdout.trim() } else { stderr.trim() });
    }
    Ok(String::from_utf8(output.stdout)?.trim_end_matches('\n').to_owned())
}

pub fn refresh() {
    if call("reloadConfig", &[]).is_err() {
        let _ = Command::new("strata-shell")
            .args(["-q", "shell", "rescanPlugins"])
            .status();
    }
}
