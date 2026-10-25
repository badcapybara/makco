use anyhow::{anyhow, Result};
use serde_json::Value;

use crate::config::{vehicle_type_for_mode, Config};

pub struct MtClient {
    base_url: String,
    merchant_id: String,
    client_id: String,
    http: reqwest::Client,
}

impl MtClient {
    pub fn new(cfg: &Config) -> Result<Self> {
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(15))
            .build()?;
        Ok(Self {
            base_url: cfg.mt_base_url.clone(),
            merchant_id: cfg.merchant_id.clone(),
            client_id: cfg.client_id.clone(),
            http,
        })
    }

    async fn request(
        &self,
        method: reqwest::Method,
        path: &str,
        token: Option<&str>,
        body: Option<Value>,
        query: Vec<(&str, String)>,
    ) -> Result<Value> {
        let url = format!("{}/{}", self.base_url, path.trim_start_matches('/'));
        let mut req = self.http.request(method, &url);
        req = req.header("Content-Type", "application/json");
        if let Some(t) = token {
            req = req.header("token", t);
        }
        if !query.is_empty() {
            req = req.query(&query);
        }
        if let Some(b) = body {
            req = req.json(&b);
        }
        let resp = req
            .send()
            .await
            .map_err(|e| anyhow!("upstream error: {e}"))?;
        let status = resp.status();
        let text = resp.text().await.unwrap_or_default();
        if text.trim().is_empty() {
            return Ok(Value::Null);
        }
        match serde_json::from_str::<Value>(&text) {
            Ok(v) => {
                if status.is_client_error() || status.is_server_error() {
                    Ok(v)
                } else {
                    Ok(v)
                }
            }
            Err(_) => Ok(serde_json::json!({
                "error": "Failed to parse response",
                "raw": text,
                "status": status.as_u16()
            })),
        }
    }

    // ---- Auth ----
    pub async fn mt_auth(&self, phone: &str, country_code: &str) -> Result<Value> {
        let body = serde_json::json!({
            "mobileNumber": phone,
            "mobileCountryCode": country_code,
            "merchantId": self.merchant_id,
            "clientId": self.client_id
        });
        self.request(reqwest::Method::POST, "auth", None, Some(body), vec![])
            .await
    }

    pub async fn mt_verify_auth(
        &self,
        auth_id: &str,
        otp: &str,
        device_token: &str,
    ) -> Result<Value> {
        let body = serde_json::json!({"otp": otp, "deviceToken": device_token});
        self.request(
            reqwest::Method::POST,
            &format!("auth/{auth_id}/verify"),
            None,
            Some(body),
            vec![],
        )
        .await
    }

    // ---- Transit data (generic across modes) ----
    pub async fn mt_get_stations(&self, token: &str, city: &str, mode: &str) -> Result<Value> {
        let query = vec![
            ("city", city.to_string()),
            ("vehicleType", vehicle_type_for_mode(mode)),
        ];
        self.request(
            reqwest::Method::GET,
            "frfs/stations",
            Some(token),
            None,
            query,
        )
        .await
    }

    pub async fn mt_get_routes(&self, token: &str, city: &str, mode: &str) -> Result<Value> {
        let query = vec![
            ("city", city.to_string()),
            ("vehicleType", vehicle_type_for_mode(mode)),
        ];
        self.request(
            reqwest::Method::GET,
            "frfs/routes",
            Some(token),
            None,
            query,
        )
        .await
    }

    pub async fn mt_get_active_routes(&self, token: &str, city: &str, mode: &str) -> Result<Value> {
        let query = vec![
            ("city", city.to_string()),
            ("vehicleType", vehicle_type_for_mode(mode)),
        ];
        self.request(
            reqwest::Method::GET,
            "frfs/activeRoutes",
            Some(token),
            None,
            query,
        )
        .await
    }

    pub async fn mt_get_route_stops(
        &self,
        token: &str,
        city: &str,
        mode: &str,
        route_code: &str,
    ) -> Result<Value> {
        let query = vec![
            ("city", city.to_string()),
            ("vehicleType", vehicle_type_for_mode(mode)),
        ];
        let path = format!("frfs/route/{route_code}/stops");
        self.request(reqwest::Method::GET, &path, Some(token), None, query)
            .await
    }

    pub async fn mt_get_possible_stops(
        &self,
        token: &str,
        city: &str,
        mode: &str,
    ) -> Result<Value> {
        let query = vec![
            ("city", city.to_string()),
            ("vehicleType", vehicle_type_for_mode(mode)),
        ];
        self.request(
            reqwest::Method::POST,
            "frfs/stations/possibleStops",
            Some(token),
            None,
            query,
        )
        .await
    }

    pub async fn mt_search_fare(
        &self,
        token: &str,
        city: &str,
        mode: &str,
        from: &str,
        to: &str,
        qty: i64,
    ) -> Result<Value> {
        let body = serde_json::json!({
            "fromStationCode": from,
            "toStationCode": to,
            "quantity": qty
        });
        let query = vec![
            ("city", city.to_string()),
            ("vehicleType", vehicle_type_for_mode(mode)),
        ];
        self.request(
            reqwest::Method::POST,
            "frfs/search",
            Some(token),
            Some(body),
            query,
        )
        .await
    }

    pub async fn mt_get_quote(
        &self,
        token: &str,
        city: &str,
        mode: &str,
        search_id: &str,
    ) -> Result<Value> {
        let query = vec![
            ("city", city.to_string()),
            ("vehicleType", vehicle_type_for_mode(mode)),
        ];
        let path = format!("frfs/search/{search_id}/quote");
        self.request(reqwest::Method::GET, &path, Some(token), None, query)
            .await
    }

    pub async fn mt_confirm_booking(
        &self,
        token: &str,
        city: &str,
        mode: &str,
        quote_id: &str,
        qty: i64,
    ) -> Result<Value> {
        let body = serde_json::json!({"quantity": qty});
        let query = vec![
            ("city", city.to_string()),
            ("vehicleType", vehicle_type_for_mode(mode)),
        ];
        let path = format!("frfs/quote/{quote_id}/confirm");
        self.request(reqwest::Method::POST, &path, Some(token), Some(body), query)
            .await
    }

    pub async fn mt_get_booking_status(
        &self,
        token: &str,
        city: &str,
        mode: &str,
        booking_id: &str,
    ) -> Result<Value> {
        let query = vec![
            ("city", city.to_string()),
            ("vehicleType", vehicle_type_for_mode(mode)),
        ];
        let path = format!("frfs/booking/{booking_id}/status");
        self.request(reqwest::Method::GET, &path, Some(token), None, query)
            .await
    }

    pub async fn mt_verify_ticket(
        &self,
        token: &str,
        city: &str,
        mode: &str,
        qr_data: &str,
    ) -> Result<Value> {
        let query: Vec<(&str, String)> = vec![
            ("city", city.to_string()),
            ("vehicleType", vehicle_type_for_mode(mode)),
        ];
        let body = serde_json::json!({ "qrData": qr_data });
        self.request(
            reqwest::Method::POST,
            "frfs/ticket/verify",
            Some(token),
            Some(body),
            query,
        )
        .await
    }

    pub async fn mt_get_profile(&self, token: &str) -> Result<Value> {
        self.request(reqwest::Method::GET, "profile", Some(token), None, vec![])
            .await
    }

    pub async fn mt_get_ticket_bookings(
        &self,
        token: &str,
        city: &str,
        mode: &str,
    ) -> Result<Value> {
        let query = vec![
            ("city", city.to_string()),
            ("vehicleType", vehicle_type_for_mode(mode)),
            ("limit", "20".to_string()),
            ("offset", "0".to_string()),
        ];
        self.request(
            reqwest::Method::GET,
            "frfs/booking/list",
            Some(token),
            None,
            query,
        )
        .await
    }
}
