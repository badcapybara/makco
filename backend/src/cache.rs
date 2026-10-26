use std::collections::HashMap;
use std::hash::{Hash, Hasher};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use serde_json::Value;

struct Entry {
    value: Value,
    expires_at: Instant,
}

static CACHE: OnceLock<Mutex<HashMap<String, Entry>>> = OnceLock::new();

fn entries() -> &'static Mutex<HashMap<String, Entry>> {
    CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

pub fn get(key: &str) -> Option<Value> {
    let mut map = entries().lock().ok()?;
    match map.get(key) {
        Some(entry) if entry.expires_at > Instant::now() => Some(entry.value.clone()),
        Some(_) => {
            map.remove(key);
            None
        }
        None => None,
    }
}

pub fn put(key: String, value: &Value, ttl: Duration) {
    if let Ok(mut map) = entries().lock() {
        if map.len() >= 512 {
            let now = Instant::now();
            map.retain(|_, entry| entry.expires_at > now);
        }
        map.insert(
            key,
            Entry {
                value: value.clone(),
                expires_at: Instant::now() + ttl,
            },
        );
    }
}

pub fn remove_prefix(prefix: &str) {
    if let Ok(mut map) = entries().lock() {
        map.retain(|key, _| !key.starts_with(prefix));
    }
}

pub fn token_key(token: &str) -> String {
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    token.hash(&mut hasher);
    format!("{:x}", hasher.finish())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn caches_values_until_they_expire() {
        let key = "test:cache:value".to_string();
        put(
            key.clone(),
            &serde_json::json!({"ok": true}),
            Duration::from_secs(5),
        );
        assert_eq!(get(&key), Some(serde_json::json!({"ok": true})));

        let expired = "test:cache:expired".to_string();
        put(
            expired.clone(),
            &serde_json::json!({"ok": true}),
            Duration::ZERO,
        );
        assert_eq!(get(&expired), None);
    }

    #[test]
    fn removes_only_matching_keys() {
        put(
            "test:remove:a".into(),
            &serde_json::json!(1),
            Duration::from_secs(30),
        );
        put(
            "test:remove:b".into(),
            &serde_json::json!(2),
            Duration::from_secs(30),
        );
        put(
            "test:keep:a".into(),
            &serde_json::json!(3),
            Duration::from_secs(30),
        );
        remove_prefix("test:remove:");
        assert_eq!(get("test:remove:a"), None);
        assert_eq!(get("test:remove:b"), None);
        assert_eq!(get("test:keep:a"), Some(serde_json::json!(3)));
    }

    #[test]
    fn token_keys_are_stable_and_scoped() {
        assert_eq!(token_key("abc"), token_key("abc"));
        assert_ne!(token_key("abc"), token_key("abd"));
        assert!(!token_key("abc").contains("abc"));
    }
}
