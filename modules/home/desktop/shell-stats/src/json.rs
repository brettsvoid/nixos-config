//! Just enough JSON writing for flat records of numbers and short strings.

use std::fmt::Write;

pub struct Object {
    out: String,
    first: bool,
}

impl Object {
    pub fn new() -> Self {
        Object {
            out: String::from("{"),
            first: true,
        }
    }

    fn key(&mut self, key: &str) {
        if !self.first {
            self.out.push(',');
        }
        self.first = false;
        string(&mut self.out, key);
        self.out.push(':');
    }

    pub fn number(&mut self, key: &str, value: f64) -> &mut Self {
        self.key(key);
        number(&mut self.out, value);
        self
    }

    pub fn optional(&mut self, key: &str, value: Option<f64>) -> &mut Self {
        self.key(key);
        match value {
            Some(v) => number(&mut self.out, v),
            None => self.out.push_str("null"),
        }
        self
    }

    pub fn text(&mut self, key: &str, value: &str) -> &mut Self {
        self.key(key);
        string(&mut self.out, value);
        self
    }

    /// A value that is already JSON (an object or array built with these helpers).
    pub fn raw(&mut self, key: &str, json: &str) -> &mut Self {
        self.key(key);
        self.out.push_str(json);
        self
    }

    pub fn finish(&mut self) -> String {
        self.out.push('}');
        std::mem::take(&mut self.out)
    }
}

pub fn array(items: &[String]) -> String {
    format!("[{}]", items.join(","))
}

pub fn numbers(values: &[f64]) -> String {
    let mut out = String::from("[");
    for (i, v) in values.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        number(&mut out, *v);
    }
    out.push(']');
    out
}

fn number(out: &mut String, value: f64) {
    if value.is_finite() {
        // One decimal is plenty for percentages and degrees; byte counts are whole.
        if value.fract() == 0.0 {
            let _ = write!(out, "{}", value as i64);
        } else {
            let _ = write!(out, "{:.1}", value);
        }
    } else {
        out.push_str("null");
    }
}

fn string(out: &mut String, value: &str) {
    out.push('"');
    for c in value.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            c if (c as u32) < 0x20 => {
                let _ = write!(out, "\\u{:04x}", c as u32);
            }
            c => out.push(c),
        }
    }
    out.push('"');
}
