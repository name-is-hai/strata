//! The privileged helper owns rules and watches this dedicated bus connection.
//! Dropping the connection releases the allowance even after daemon SIGKILL.
use std::{net::Ipv4Addr, sync::OnceLock, time::Duration};
use tokio::sync::Mutex;

fn owner() -> &'static Mutex<Option<zbus::Connection>> {
    static OWNER: OnceLock<Mutex<Option<zbus::Connection>>> = OnceLock::new();
    OWNER.get_or_init(|| Mutex::new(None))
}

pub async fn open(receiver: &str, bind: Ipv4Addr, port: u16) -> Result<(), String> {
    let mut guard = owner().lock().await;
    if guard.is_some() {
        return Err("Media firewall session already exists".into());
    }
    let connection = zbus::Connection::system()
        .await
        .map_err(|e| e.to_string())?;
    let proxy = zbus::Proxy::new(
        &connection,
        "org.waycast.Network1",
        "/org/waycast/Network1",
        "org.waycast.Network1",
    )
    .await
    .map_err(|e| e.to_string())?;
    let result: Result<(), _> = tokio::time::timeout(
        Duration::from_secs(90),
        proxy.call::<_, _, ()>("OpenMedia", &(receiver, bind.to_string(), port)),
    )
    .await
    .map_err(|_| "Media firewall request timed out".to_string())?;
    result.map_err(|e| e.to_string())?;
    drop(proxy);
    *guard = Some(connection);
    Ok(())
}

pub async fn clear() {
    let mut guard = owner().lock().await;
    if let Some(connection) = guard.take() {
        if let Ok(proxy) = zbus::Proxy::new(
            &connection,
            "org.waycast.Network1",
            "/org/waycast/Network1",
            "org.waycast.Network1",
        )
        .await
        {
            match tokio::time::timeout(
                Duration::from_secs(20),
                proxy.call::<_, _, ()>("CloseMedia", &()),
            )
            .await
            {
                Ok(Ok(())) => {}
                error => tracing::warn!(
                    ?error,
                    "Explicit firewall cleanup failed; helper will retry after connection closes"
                ),
            }
        }
        // The independent root helper keeps the journal until removal succeeds.
        let _ = connection.close().await;
    }
}
