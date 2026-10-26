mod api_client;
mod cache;
mod config;
mod handlers;

use axum::{
    routing::{get, post},
    Router,
};
use tower_http::cors::CorsLayer;
use tower_http::trace::{DefaultMakeSpan, DefaultOnResponse, TraceLayer};
use tracing::Level;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "makco=info,tower_http=info".into()),
        )
        .init();

    let cfg = config::config_from_env()?;
    let port = cfg.port;
    handlers::init_client(&cfg);

    let cors = CorsLayer::permissive();

    let app = Router::new()
        .route("/", get(handlers::health))
        // Auth
        .route("/auth", post(handlers::init_auth))
        .route("/auth/:auth_id/verify", post(handlers::verify_auth))
        // Transit data
        .route("/transit/stations", get(handlers::get_stations))
        .route("/transit/routes", get(handlers::get_routes))
        .route("/transit/routes/active", get(handlers::get_active_routes))
        .route(
            "/transit/route/:route_code/stops",
            get(handlers::get_route_stops),
        )
        .route("/transit/stops/possible", get(handlers::get_possible_stops))
        // Search / quote / booking
        .route("/transit/search", post(handlers::search_fare))
        .route("/transit/search/:search_id/quote", get(handlers::get_quote))
        .route(
            "/transit/quote/:quote_id/confirm",
            post(handlers::confirm_booking),
        )
        .route(
            "/transit/booking/:booking_id/status",
            get(handlers::get_booking_status),
        )
        .route(
            "/transit/booking/:booking_id/refresh",
            get(handlers::refresh_booking_status),
        )
        .route("/transit/ticket/verify", post(handlers::verify_ticket))
        // User
        .route("/profile", get(handlers::get_profile))
        .route("/tickets", get(handlers::get_ticket_bookings))
        // Legacy metro aliases for back-compat with v2 clients
        .route("/metro/stations", get(handlers::get_stations))
        .route("/metro/routes", get(handlers::get_routes))
        .route("/metro/search", post(handlers::search_fare))
        .route("/metro/search/:search_id/quote", get(handlers::get_quote))
        .route(
            "/metro/quote/:quote_id/confirm",
            post(handlers::confirm_booking),
        )
        .route(
            "/booking/:booking_id/status",
            get(handlers::get_booking_status),
        )
        .route(
            "/booking/:booking_id/refresh",
            get(handlers::refresh_booking_status),
        )
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(DefaultMakeSpan::new().level(Level::INFO))
                .on_response(DefaultOnResponse::new().level(Level::INFO)),
        )
        .layer(cors);

    let addr = format!("0.0.0.0:{port}");
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    tracing::info!("Makco v3.3.3 serving metro transit API at http://{addr}");
    axum::serve(listener, app).await?;
    Ok(())
}
