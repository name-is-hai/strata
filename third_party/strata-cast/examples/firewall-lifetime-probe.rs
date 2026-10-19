//! Manual integration fixture for the root helper. Open one scoped allowance,
//! then let a test driver disconnect, SIGKILL this process, or kill the helper.
//! Run only on a test LAN with STRATA_TEST_RECEIVER and STRATA_TEST_BIND set.
#[path = "../src/firewall.rs"]
mod firewall;

#[tokio::main]
async fn main() {
    let receiver = std::env::var("STRATA_TEST_RECEIVER").expect("test receiver required");
    let bind = std::env::var("STRATA_TEST_BIND").expect("test bind required").parse().unwrap();
    let port = std::env::var("STRATA_TEST_PORT").unwrap_or_else(|_| "60029".into()).parse().unwrap();
    firewall::open(&receiver, bind, port).await.expect("open allowance");
    println!("ALLOWANCE_READY");
    if std::env::var_os("STRATA_TEST_CLOSE").is_some() {
        firewall::clear().await;
        println!("ALLOWANCE_CLOSED");
    } else {
        tokio::time::sleep(std::time::Duration::from_secs(300)).await;
        firewall::clear().await;
    }
}
