use std::future::Future;
use std::sync::OnceLock;
use std::time::Duration;

use axum::{
    extract::Path,
    extract::Query,
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::api_client::MtClient;
use crate::cache;
use crate::config::Config;

type ApiError = (StatusCode, Json<Value>);
type ApiResult = Result<Json<Value>, ApiError>;

const CATALOG_TTL: Duration = Duration::from_secs(600);
const PROFILE_TTL: Duration = Duration::from_secs(300);
const TICKETS_TTL: Duration = Duration::from_secs(3);

fn cacheable(value: &Value) -> bool {
    !value.is_null() && value.get("errorCode").is_none() && value.get("error").is_none()
}

async fn cached_fetch<F, Fut>(
    key: String,
    ttl: Duration,
    error_code: &'static str,
    fetch: F,
) -> ApiResult
where
    F: FnOnce() -> Fut,
    Fut: Future<Output = anyhow::Result<Value>>,
{
    if let Some(value) = cache::get(&key) {
        tracing::debug!(cache = "hit", %key, "serving cached response");
        return Ok(Json(value));
    }
    let value = fetch()
        .await
        .map_err(|e| api_error(StatusCode::BAD_GATEWAY, error_code, e.to_string()))?;
    if let Some((status, code, message)) = upstream_error(&value) {
        tracing::warn!(upstream_code = %code, upstream_message = %message, "cached endpoint failed upstream");
        return Err(api_error(status, &code, message));
    }
    if cacheable(&value) {
        cache::put(key, &value, ttl);
    }
    Ok(Json(value))
}

fn api_error(status: StatusCode, code: &str, message: impl Into<String>) -> ApiError {
    (
        status,
        Json(json!({"errorCode": code, "errorMessage": message.into()})),
    )
}

fn upstream_error(value: &Value) -> Option<(StatusCode, String, String)> {
    let code = value.get("errorCode").and_then(|v| v.as_str())?;
    let message = value
        .get("errorMessage")
        .or_else(|| value.get("message"))
        .and_then(|v| v.as_str())
        .unwrap_or("Upstream request failed");
    let status = match code {
        "INVALID_TOKEN" => StatusCode::UNAUTHORIZED,
        "BOOKING_NOT_FOUND" | "INVALID_BOOKING_ID" | "INVALID_QUOTE_ID" => StatusCode::NOT_FOUND,
        _ => StatusCode::BAD_GATEWAY,
    };
    Some((status, code.to_string(), message.to_string()))
}

fn require_booking_status(value: &Value) -> Result<(), ApiError> {
    let has_booking = value
        .get("bookingId")
        .and_then(|v| v.as_str())
        .is_some_and(|s| !s.is_empty());
    let has_status = value
        .get("status")
        .and_then(|v| v.as_str())
        .is_some_and(|s| !s.is_empty());
    if !has_booking || !has_status {
        return Err(api_error(
            StatusCode::BAD_GATEWAY,
            "STATUS_UNAVAILABLE",
            "The operator returned no booking status. Please try again.",
        ));
    }
    Ok(())
}

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
pub struct VerifyTicketBody {
    #[serde(rename = "qrData", default)]
    pub qr_data: Option<String>,
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
        "version": "3.3.3",
        "modes": ["bus", "metro"]
    }))
}

pub async fn init_auth(Json(body): Json<AuthBody>) -> ApiResult {
    let phone = body.phone();
    if phone.len() != 10 || !phone.chars().all(|c| c.is_ascii_digit()) {
        return Err(api_error(
            StatusCode::BAD_REQUEST,
            "INVALID_PHONE",
            "Phone number must be 10 digits",
        ));
    }
    match client().mt_auth(&phone, &body.country()).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(api_error(
            StatusCode::BAD_GATEWAY,
            "AUTH_FAILED",
            e.to_string(),
        )),
    }
}

pub async fn verify_auth(Path(auth_id): Path<String>, Json(body): Json<VerifyBody>) -> ApiResult {
    if auth_id.is_empty() {
        return Err(api_error(
            StatusCode::BAD_REQUEST,
            "MISSING_AUTH_ID",
            "Missing authId",
        ));
    }
    let otp = body.otp.unwrap_or_default();
    if otp.len() != 4 || !otp.chars().all(|c| c.is_ascii_digit()) {
        return Err(api_error(
            StatusCode::BAD_REQUEST,
            "INVALID_OTP",
            "OTP must be 4 digits",
        ));
    }
    let device = body
        .device_token
        .or(body.device_token_alt)
        .unwrap_or_else(|| "makco_device".to_string());
    match client().mt_verify_auth(&auth_id, &otp, &device).await {
        Ok(r) => Ok(Json(r)),
        Err(e) => Err(api_error(
            StatusCode::BAD_GATEWAY,
            "VERIFY_FAILED",
            e.to_string(),
        )),
    }
}

fn require_token(headers: &HeaderMap) -> Result<String, ApiError> {
    token_from(headers).ok_or_else(|| {
        api_error(
            StatusCode::UNAUTHORIZED,
            "MISSING_HEADER",
            "Header token is missing",
        )
    })
}

pub async fn get_stations(Query(q): Query<CtyQuery>, headers: HeaderMap) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    cached_fetch(
        format!("stations:{city}:{mode}"),
        CATALOG_TTL,
        "STATIONS_FAILED",
        || client().mt_get_stations(&token, &city, &mode),
    )
    .await
}

pub async fn get_routes(Query(q): Query<CtyQuery>, headers: HeaderMap) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    cached_fetch(
        format!("routes:{city}:{mode}"),
        CATALOG_TTL,
        "ROUTES_FAILED",
        || client().mt_get_routes(&token, &city, &mode),
    )
    .await
}

pub async fn get_active_routes(Query(q): Query<CtyQuery>, headers: HeaderMap) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    cached_fetch(
        format!("active-routes:{city}:{mode}"),
        CATALOG_TTL,
        "ACTIVE_ROUTES_FAILED",
        || client().mt_get_active_routes(&token, &city, &mode),
    )
    .await
}

pub async fn get_route_stops(
    Path((route_code,)): Path<(String,)>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    cached_fetch(
        format!("route-stops:{city}:{mode}:{route_code}"),
        CATALOG_TTL,
        "ROUTE_STOPS_FAILED",
        || client().mt_get_route_stops(&token, &city, &mode, &route_code),
    )
    .await
}

pub async fn get_possible_stops(Query(q): Query<CtyQuery>, headers: HeaderMap) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    cached_fetch(
        format!("possible-stops:{city}:{mode}"),
        CATALOG_TTL,
        "POSSIBLE_STOPS_FAILED",
        || client().mt_get_possible_stops(&token, &city, &mode),
    )
    .await
}

pub async fn search_fare(
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
    Json(body): Json<SearchBody>,
) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    let from = body.from_station_code.unwrap_or_default();
    let to = body.to_station_code.unwrap_or_default();
    let qty = body.quantity.unwrap_or(1);
    if from.is_empty() || to.is_empty() {
        return Err(api_error(
            StatusCode::BAD_REQUEST,
            "MISSING_STATIONS",
            "Both station codes are required",
        ));
    }
    if qty < 1 || qty > 6 {
        return Err(api_error(
            StatusCode::BAD_REQUEST,
            "INVALID_QUANTITY",
            "Quantity must be between 1 and 6",
        ));
    }
    client()
        .mt_search_fare(&token, &city, &mode, &from, &to, qty)
        .await
        .map(Json)
        .map_err(|e| api_error(StatusCode::BAD_GATEWAY, "SEARCH_FAILED", e.to_string()))
}

pub async fn get_quote(
    Path(search_id): Path<String>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    client()
        .mt_get_quote(&token, &city, &mode, &search_id)
        .await
        .map(Json)
        .map_err(|e| api_error(StatusCode::BAD_GATEWAY, "QUOTE_FAILED", e.to_string()))
}

pub async fn confirm_booking(
    Path(quote_id): Path<String>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
    Json(body): Json<ConfirmBody>,
) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    let qty = body.quantity.unwrap_or(1);
    if qty < 1 || qty > 6 {
        return Err(api_error(
            StatusCode::BAD_REQUEST,
            "INVALID_QUANTITY",
            "Quantity must be between 1 and 6",
        ));
    }

    match client()
        .mt_confirm_booking(&token, &city, &mode, &quote_id, qty)
        .await
    {
        Ok(r) => {
            if let Some((status, code, message)) = upstream_error(&r) {
                tracing::warn!(
                    booking_id = %r.get("bookingId").and_then(|v| v.as_str()).unwrap_or(""),
                    upstream_code = %code,
                    upstream_message = %message,
                    "booking confirm failed upstream"
                );
                return Err(api_error(
                    status,
                    "CONFIRM_FAILED",
                    format!("{code}: {message}"),
                ));
            }
            if r.get("bookingId").and_then(|v| v.as_str()).is_none() {
                tracing::warn!(body = ?r, "booking confirm returned no booking");
                return Err(api_error(
                    StatusCode::BAD_GATEWAY,
                    "CONFIRM_FAILED",
                    "The operator did not create a booking. Please try again.",
                ));
            }
            cache::remove_prefix(&format!("tickets:{}:", cache::token_key(&token)));
            tracing::info!(
                booking_id = %r.get("bookingId").and_then(|v| v.as_str()).unwrap_or(""),
                status = %r.get("status").and_then(|v| v.as_str()).unwrap_or(""),
                payment = %r
                    .get("payment")
                    .and_then(|p| p.get("status"))
                    .and_then(|v| v.as_str())
                    .unwrap_or(""),
                payment_order = %r
                    .get("payment")
                    .and_then(|p| p.get("paymentOrder"))
                    .and_then(|p| p.get("status"))
                    .and_then(|v| v.as_str())
                    .unwrap_or(""),
                has_payment_link = r
                    .get("payment")
                    .and_then(|p| p.get("paymentOrder"))
                    .and_then(|p| p.get("payment_links"))
                    .and_then(|p| p.get("web"))
                    .and_then(|v| v.as_str())
                    .is_some(),
                "booking confirmed"
            );
            Ok(Json(r))
        }
        Err(e) => Err(api_error(
            StatusCode::BAD_GATEWAY,
            "CONFIRM_FAILED",
            e.to_string(),
        )),
    }
}

pub async fn get_booking_status(
    Path(booking_id): Path<String>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    match client()
        .mt_get_booking_status(&token, &city, &mode, &booking_id)
        .await
    {
        Ok(r) => {
            if let Some((status, code, message)) = upstream_error(&r) {
                tracing::warn!(
                    booking_id = %booking_id,
                    upstream_code = %code,
                    upstream_message = %message,
                    "booking status failed upstream"
                );
                return Err(api_error(
                    status,
                    "STATUS_FAILED",
                    format!("{code}: {message}"),
                ));
            }
            if let Err(e) = require_booking_status(&r) {
                tracing::warn!(booking_id = %booking_id, body = ?r, "booking status missing");
                return Err(e);
            }
            tracing::info!(
                booking_id = %booking_id,
                status = %r.get("status").and_then(|v| v.as_str()).unwrap_or(""),
                payment = %r
                    .get("payment")
                    .and_then(|p| p.get("status"))
                    .and_then(|v| v.as_str())
                    .unwrap_or(""),
                payment_order = %r
                    .get("payment")
                    .and_then(|p| p.get("paymentOrder"))
                    .and_then(|p| p.get("status"))
                    .and_then(|v| v.as_str())
                    .unwrap_or(""),
                has_payment_link = r
                    .get("payment")
                    .and_then(|p| p.get("paymentOrder"))
                    .and_then(|p| p.get("payment_links"))
                    .and_then(|p| p.get("web"))
                    .and_then(|v| v.as_str())
                    .is_some(),
                tickets = r
                    .get("tickets")
                    .and_then(|v| v.as_array())
                    .map(|a| a.len())
                    .unwrap_or(0),
                "booking status"
            );
            Ok(Json(r))
        }
        Err(e) => Err(api_error(
            StatusCode::BAD_GATEWAY,
            "STATUS_FAILED",
            e.to_string(),
        )),
    }
}

pub async fn refresh_booking_status(
    Path(booking_id): Path<String>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
) -> ApiResult {
    get_booking_status(Path(booking_id), Query(q), headers).await
}

pub async fn verify_ticket(
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
    Json(body): Json<VerifyTicketBody>,
) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    let qr_data = body.qr_data.as_deref().unwrap_or_default();
    if qr_data.is_empty() {
        return Err(api_error(
            StatusCode::BAD_REQUEST,
            "MISSING_QR",
            "qrData is required",
        ));
    }
    client()
        .mt_verify_ticket(&token, &city, &mode, qr_data)
        .await
        .map(Json)
        .map_err(|e| {
            api_error(
                StatusCode::BAD_GATEWAY,
                "VERIFY_TICKET_FAILED",
                e.to_string(),
            )
        })
}

pub async fn get_profile(headers: HeaderMap) -> ApiResult {
    let token = require_token(&headers)?;
    let key = format!("profile:{}", cache::token_key(&token));
    cached_fetch(key, PROFILE_TTL, "PROFILE_FAILED", || {
        client().mt_get_profile(&token)
    })
    .await
}

pub async fn get_ticket_bookings(Query(q): Query<CtyQuery>, headers: HeaderMap) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    let key = format!("tickets:{}:{city}:{mode}", cache::token_key(&token));
    cached_fetch(key, TICKETS_TTL, "TICKETS_FAILED", || {
        client().mt_get_ticket_bookings(&token, &city, &mode)
    })
    .await
}

static CLIENT: OnceLock<MtClient> = OnceLock::new();

fn client() -> &'static MtClient {
    CLIENT.get().expect("Makco client not initialized")
}

pub fn init_client(cfg: &Config) {
    let _ = CLIENT.set(MtClient::new(cfg).expect("failed to build MovingTech client"));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn booking_status_requires_booking_and_status_fields() {
        assert!(require_booking_status(&json!({})).is_err());
        assert!(require_booking_status(&json!({"bookingId": "b1"})).is_err());
        assert!(require_booking_status(&json!({"status": "NEW"})).is_err());
        assert!(require_booking_status(&json!({"bookingId": "b1", "status": "NEW"})).is_ok());
    }

    #[test]
    fn upstream_auth_errors_map_to_unauthorized() {
        let (status, code, _) =
            upstream_error(&json!({"errorCode": "INVALID_TOKEN", "errorMessage": "bad"})).unwrap();
        assert_eq!(status, StatusCode::UNAUTHORIZED);
        assert_eq!(code, "INVALID_TOKEN");
    }

    #[test]
    fn upstream_missing_booking_maps_to_not_found() {
        let (status, _, _) =
            upstream_error(&json!({"errorCode": "BOOKING_NOT_FOUND", "errorMessage": "gone"}))
                .unwrap();
        assert_eq!(status, StatusCode::NOT_FOUND);
    }

    #[test]
    fn missing_error_code_is_not_an_upstream_error() {
        assert!(upstream_error(&json!({"bookingId": "b1", "status": "NEW"})).is_none());
    }

    #[tokio::test]
    async fn cached_fetch_reuses_successful_responses() {
        use std::sync::atomic::{AtomicUsize, Ordering};
        use std::sync::Arc;

        let calls = Arc::new(AtomicUsize::new(0));
        let key = format!("test:cached-fetch:{}", std::process::id());
        let first_calls = calls.clone();
        let first = cached_fetch(key.clone(), CATALOG_TTL, "TEST_FAILED", || async move {
            first_calls.fetch_add(1, Ordering::SeqCst);
            Ok(json!({"ok": true}))
        })
        .await
        .unwrap();
        assert_eq!(first.0, json!({"ok": true}));

        let second_calls = calls.clone();
        let second = cached_fetch(key, CATALOG_TTL, "TEST_FAILED", || async move {
            second_calls.fetch_add(1, Ordering::SeqCst);
            Ok(json!({"ok": false}))
        })
        .await
        .unwrap();
        assert_eq!(second.0, json!({"ok": true}));
        assert_eq!(calls.load(Ordering::SeqCst), 1);
    }
}
