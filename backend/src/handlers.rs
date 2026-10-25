use std::sync::OnceLock;

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
use crate::config::Config;

type ApiError = (StatusCode, Json<Value>);
type ApiResult = Result<Json<Value>, ApiError>;

fn api_error(status: StatusCode, code: &str, message: impl Into<String>) -> ApiError {
    (
        status,
        Json(json!({"errorCode": code, "errorMessage": message.into()})),
    )
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
        "version": "3.3.0",
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
    client()
        .mt_get_stations(&token, &city, &mode)
        .await
        .map(Json)
        .map_err(|e| api_error(StatusCode::BAD_GATEWAY, "STATIONS_FAILED", e.to_string()))
}

pub async fn get_routes(Query(q): Query<CtyQuery>, headers: HeaderMap) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    client()
        .mt_get_routes(&token, &city, &mode)
        .await
        .map(Json)
        .map_err(|e| api_error(StatusCode::BAD_GATEWAY, "ROUTES_FAILED", e.to_string()))
}

pub async fn get_active_routes(Query(q): Query<CtyQuery>, headers: HeaderMap) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    client()
        .mt_get_active_routes(&token, &city, &mode)
        .await
        .map(Json)
        .map_err(|e| {
            api_error(
                StatusCode::BAD_GATEWAY,
                "ACTIVE_ROUTES_FAILED",
                e.to_string(),
            )
        })
}

pub async fn get_route_stops(
    Path((route_code,)): Path<(String,)>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    client()
        .mt_get_route_stops(&token, &city, &mode, &route_code)
        .await
        .map(Json)
        .map_err(|e| api_error(StatusCode::BAD_GATEWAY, "ROUTE_STOPS_FAILED", e.to_string()))
}

pub async fn get_possible_stops(Query(q): Query<CtyQuery>, headers: HeaderMap) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    client()
        .mt_get_possible_stops(&token, &city, &mode)
        .await
        .map(Json)
        .map_err(|e| {
            api_error(
                StatusCode::BAD_GATEWAY,
                "POSSIBLE_STOPS_FAILED",
                e.to_string(),
            )
        })
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

    client()
        .mt_confirm_booking(&token, &city, &mode, &quote_id, qty)
        .await
        .map(Json)
        .map_err(|e| api_error(StatusCode::BAD_GATEWAY, "CONFIRM_FAILED", e.to_string()))
}

pub async fn get_booking_status(
    Path(booking_id): Path<String>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    client()
        .mt_get_booking_status(&token, &city, &mode, &booking_id)
        .await
        .map(Json)
        .map_err(|e| api_error(StatusCode::BAD_GATEWAY, "STATUS_FAILED", e.to_string()))
}

pub async fn refresh_booking_status(
    Path(booking_id): Path<String>,
    Query(q): Query<CtyQuery>,
    headers: HeaderMap,
) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    client()
        .mt_get_booking_status(&token, &city, &mode, &booking_id)
        .await
        .map(Json)
        .map_err(|e| api_error(StatusCode::BAD_GATEWAY, "REFRESH_FAILED", e.to_string()))
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
    client()
        .mt_get_profile(&token)
        .await
        .map(Json)
        .map_err(|e| api_error(StatusCode::BAD_GATEWAY, "PROFILE_FAILED", e.to_string()))
}

pub async fn get_ticket_bookings(Query(q): Query<CtyQuery>, headers: HeaderMap) -> ApiResult {
    let token = require_token(&headers)?;
    let mode = mode_of(&q);
    let city = city_of(&q);
    client()
        .mt_get_ticket_bookings(&token, &city, &mode)
        .await
        .map(Json)
        .map_err(|e| api_error(StatusCode::BAD_GATEWAY, "TICKETS_FAILED", e.to_string()))
}

static CLIENT: OnceLock<MtClient> = OnceLock::new();

fn client() -> &'static MtClient {
    CLIENT.get().expect("Makco client not initialized")
}

pub fn init_client(cfg: &Config) {
    let _ = CLIENT.set(MtClient::new(cfg).expect("failed to build MovingTech client"));
}
