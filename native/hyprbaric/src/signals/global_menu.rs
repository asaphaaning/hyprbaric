use rinf::{DartSignal, RustSignal, SignalPiece};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, DartSignal)]
pub struct GlobalMenuRequest;

#[derive(Serialize, RustSignal)]
pub struct GlobalMenuStatus {
    pub sections: Vec<GlobalMenuSection>,
    pub message: Option<String>,
}

#[derive(Serialize, SignalPiece, Clone, Debug, PartialEq, Eq)]
pub struct GlobalMenuSection {
    pub id: i32,
    pub label: String,
    pub enabled: bool,
    pub items: Vec<GlobalMenuItem>,
}

#[derive(Serialize, SignalPiece, Clone, Debug, PartialEq, Eq)]
pub struct GlobalMenuItem {
    pub id: i32,
    pub label: String,
    pub enabled: bool,
    pub separator: bool,
}
