use std::sync::OnceLock;

use axum::{extract::Path, extract::Query, http::HeaderMap, response::IntoResponse, Json};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::api_client::MtClient;
use crate::config::Config;

#[derive(Deserialize)]
pub struct AuthBody {
    pub mobile_number: Option<String>,
    #[serde(rename = "mobileNumber")]
    pub mobile_number_alt: Option<String>,
    pub mobile_country_code: Option<String>,
    #[serde(rename = "mobileCountryCode")]
    pub mobile_country_code_alt: Option<String>,
}

impl AuthBody {
    pub fn phone(&self) -> String {
        self.mobile_number
            .clone()
            .or_else(|| self.mobile_number_alt.clone())
            .unwrap_or_default()
    }
    pub fn country(&self) -> String {
        self.mobile_country_code
            .clone()
            .or_else(|| self.mobile_country_code_alt.clone())
            .unwrap_or_else(|| "+91".to_string())
    }
}

#[derive(Deserialize)]
pub struct VerifyBody {
    pub otp: Option<String>,
    pub device_token: Option<String>,
    #[serde(rename = "deviceToken")]
    pub device_token_alt: Option<String>,
}

#[derive(Deserialize)]
pub struct SearchBody {
    #[serde(rename = "fromStationCode", default)]
    pub from_station_code: Option<String>,
    #[serde(rename = "toStationCode", default)]
    pub to_station_code: Option<String>,
    #[serde(default)]
    pub quantity: Option<i64>,
}

#[derive(Deserialize)]
pub struct ConfirmBody {
    #[serde(default)]
    pub quantity: Option<i64>,
}

#[derive(Deserialize)]
pub struct CtyQuery {
    pub city: Option<String>,
    pub mode: Option<String>,
}

#[derive(Deserialize)]
pub struct TicketQuery {
    pub city: Option<String>,
    pub mode: Option<String>,
    #[serde(rename = "ticketRef", default)]
    pub ticket_ref: Option<String>,
}

fn token_from(headers: &HeaderMap) -> Option<String> {
    headers
        .get("token")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string())
}

fn mode_of(q: &CtyQuery) -> String {
    q.mode.as_deref().unwrap_or("metro").to_lowercase()
}

fn city_of(q: &CtyQuery) -> String {
    q.city.clone().unwrap_or_else(|| "chennai".to_string())
}

pub async fn health() -> impl IntoResponse {
    Json(json!({
        "status": "ok",
        "app": "Makco",
        "version": "3.0.0",
        "modes": ["bus", "metro"]
    }))
}

pub async fn init_auth(Json(body): Json<AuthBody>) -> impl IntoResponse {
    let phone = body.phone();
    if phone.len() != 10 || !phone.chars().all(|c| c.is_ascii_digit()) {
        return Json(json!({"error": "Invalid phone number", "errorCode": "INVALID_PHONE"}));
    }
    match client().mt_auth(&phone, &body.country()).await {
        Ok(r) => Json(r),
        Err(e) => Json(json!({"error": "Auth failed", "message": e.to_string()})),
    }
}

pub async fn verify_auth(Path(auth_id): Path<String>, Json(body): Json<VerifyBody>) -> impl IntoResponse {
    if auth_id.is_empty() {
        return Json(json!({"error": "Missing authId"}));
    }
    let otp = body.otp.unwrap_or_default();
    if otp.len() != 4 || !otp.chars().all(|c| c.is_ascii_digit()) {
        return Json(json!({"error": "OTP must be 4 digits", "errorCode": "INVALID_OTP"}));
    }
    let device = body
        .device_token
        .or(body.device_token_alt)
        .unwrap_or_else(|| "makco_device".to_string());
    match client().mt_verify_auth(&auth_id, &otp, &device).await {
        Ok(r) => Json(r),
        Err(e) => Json(json!({"error": "Verify failed", "message": e.to_string()})),
    }
}

fn require_token(headers: &HeaderMap) -> Result<String, Json<Value>> {
    token_from(headers).ok_or_else(|| {
        Json(json!({
            "errorCode": "MISSING_HEADER",
            "errorMessage": "Header token is missing"
        }))
    })
}

pub async fn get_stations(Query(q): Query<CtyQuery>, headers: HeaderMap) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    match client().mt_get_stations(&token, &city, &mode).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(Json(json!({"error": "Failed to get stations", "message": e.to_string()}))),
    }
}

pub async fn get_routes(Query(q): Query<CtyQuery>, headers: HeaderMap) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    match client().mt_get_routes(&token, &city, &mode).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(Json(json!({"error": "Failed to get routes", "message": e.to_string()}))),
    }
}

pub async fn get_active_routes(Query(q): Query<CtyQuery>, headers: HeaderMap) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let city = city_of(&q);
    match client().mt_get_active_routes(&token, &city).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(Json(json!({"error": "Failed to get active routes", "message": e.to_string()}))),
    }
}

pub async fn get_route_stops(
    Path((route_code,)): Path<(String,)>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let city = city_of(&q);
    match client().mt_get_route_stops(&token, &city, &route_code).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(Json(json!({"error": "Failed to get route stops", "message": e.to_string()}))),
    }
}

pub async fn get_possible_stops(Query(q): Query<CtyQuery>, headers: HeaderMap) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let city = city_of(&q);
    match client().mt_get_possible_stops(&token, &city).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(Json(json!({"error": "Failed to get possible stops", "message": e.to_string()}))),
    }
}

pub async fn search_fare(
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
    Json(body): Json<SearchBody>,
) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    let from = body.from_station_code.unwrap_or_default();
    let to = body.to_station_code.unwrap_or_default();
    let qty = body.quantity.unwrap_or(1);
    if from.is_empty() || to.is_empty() {
        return Err(Json(json!({"error": "Missing station codes"})));
    }
    match client().mt_search_fare(&token, &city, &mode, &from, &to, qty).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(Json(json!({"error": "Search failed", "message": e.to_string()}))),
    }
}

pub async fn get_quote(
    Path(search_id): Path<String>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    match client().mt_get_quote(&token, &city, &mode, &search_id).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(Json(json!({"error": "Quote failed", "message": e.to_string()}))),
    }
}

pub async fn confirm_booking(
    Path(quote_id): Path<String>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
    Json(body): Json<ConfirmBody>,
) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    let qty = body.quantity.unwrap_or(1);

    let is_admin = match client().mt_get_profile(&token).await {
        Ok(profile) => is_admin_account(&profile),
        Err(_) => false,
    };
    if is_admin {
        tracing::info!("ADMIN verified, mock payment enabled");
    }

    match client().mt_confirm_booking(&token, &city, &mode, &quote_id, qty, is_admin).await {
        Ok(mut r) => {
            if let Some(obj) = r.as_object_mut() {
                obj.insert("isAdmin".into(), json!(is_admin));
            }
            Ok(Json(r))
        }
        Err(e) => Err(Json(json!({"error": "Confirm failed", "message": e.to_string()}))),
    }
}

pub async fn get_booking_status(
    Path(booking_id): Path<String>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    match client().mt_get_booking_status(&token, &city, &mode, &booking_id).await {
        Ok(mut r) => {
            let is_admin = match client().mt_get_profile(&token).await {
                Ok(profile) => is_admin_account(&profile),
                Err(_) => false,
            };
            if let Some(obj) = r.as_object_mut() {
                obj.insert("isAdmin".into(), json!(is_admin));
            }
            Ok(Json(r))
        }
        Err(e) => Err(Json(json!({"error": "Status failed", "message": e.to_string()}))),
    }
}

pub async fn refresh_booking_status(
    Path(booking_id): Path<String>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    match client().mt_get_booking_status(&token, &city, &mode, &booking_id).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(Json(json!({"error": "Refresh failed", "message": e.to_string()}))),
    }
}

pub async fn verify_ticket(
    Query(q): Query<TicketQuery>,
    headers: HeaderMap,
) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let mode = q.mode.as_deref().unwrap_or("metro");
    let city = q.city.clone().unwrap_or_else(|| "chennai".to_string());
    let ticket_ref = q.ticket_ref.as_deref().unwrap_or_default();
    if ticket_ref.is_empty() {
        return Err(Json(json!({"error": "Missing ticketRef"})));
    }
    match client().mt_verify_ticket(&token, &city, mode, ticket_ref).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(Json(json!({"error": "Ticket verify failed", "message": e.to_string()}))),
    }
}

pub async fn get_profile(headers: HeaderMap) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    match client().mt_get_profile(&token).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(Json(json!({"error": "Profile failed", "message": e.to_string()}))),
    }
}

pub async fn get_ticket_bookings(Query(q): Query<CtyQuery>, headers: HeaderMap) -> Result<Json<Value>, Json<Value>> {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    match client().mt_get_ticket_bookings(&token, &city, &mode).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(Json(json!({"error": "Tickets failed", "message": e.to_string()}))),
    }
}

pub fn is_admin_account(profile: &Value) -> bool {
    let phone = profile.get("maskedMobileNumber").and_then(|v| v.as_str()).unwrap_or("");
    let id = profile.get("id").and_then(|v| v.as_str()).unwrap_or("");
    let admins = std::env::var("ADMIN_PHONES").unwrap_or_else(|_| "8190835624".to_string());
    let phone_matches = admins.split(',').any(|p| phone.contains(p.trim()));
    // Admin phone(s) from ADMIN_PHONES / UUID fallback
    phone_matches || phone == "819...624" || id == "fd86b184-27ac-4f89-a7fa-c274692f9602"
}

static CLIENT: OnceLock<MtClient> = OnceLock::new();

fn client() -> &'static MtClient {
    CLIENT.get().expect("Makco client not initialized")
}

pub fn init_client(cfg: &Config) {
    let _ = CLIENT.set(MtClient::new(cfg).expect("failed to build MovingTech client"));
}