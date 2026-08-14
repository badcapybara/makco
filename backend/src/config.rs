use anyhow::Result;

pub const SERVER_PORT: u16 = 8080;

pub const MT_BASE_URL: &str = "https://api.moving.tech/pilot/app/v2";
pub const MERCHANT_ID: &str = "NAMMA_YATRI";
pub const CLIENT_ID: &str = "NAMMA_YATRI";

pub const VEHICLE_BUS_HYBRID: &str = "\"BUS_HYBRID\"";

pub fn vehicle_type_for_mode(mode: &str) -> String {
    let m = mode.to_lowercase();
    match m.as_str() {
        "bus" | "bus_hybrid" => VEHICLE_BUS_HYBRID.to_string(),
        "metro" | "metro_v2" => "\"METRO_V2\"".to_string(),
        _ => "\"METRO\"".to_string(),
    }
}

pub fn get_env(key: &str, default: &str) -> String {
    std::env::var(key).unwrap_or_else(|_| default.to_string())
}

pub fn config_from_env() -> Result<Config> {
    dotenvy::dotenv().ok();
    Ok(Config {
        port: get_env("PORT", &SERVER_PORT.to_string()).parse().unwrap_or(SERVER_PORT),
        mt_base_url: get_env("MT_BASE_URL", MT_BASE_URL),
        merchant_id: get_env("MERCHANT_ID", MERCHANT_ID),
        client_id: get_env("CLIENT_ID", CLIENT_ID),
    })
}

pub struct Config {
    pub port: u16,
    pub mt_base_url: String,
    pub merchant_id: String,
    pub client_id: String,
}