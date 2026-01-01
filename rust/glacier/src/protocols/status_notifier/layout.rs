//! DBusMenu layout.
//!
//! [`Node`] represents a single node part of DBusMenu's layout. They form a tree representing the
//! menu as a whole.

use std::collections::HashMap;

use zbus::zvariant;

/// Single menu Node.
#[derive(Default, Debug, Clone)]
pub struct Node {
    /// Node's Id.
    pub id: i32,
    /// Node's properties.
    pub props: Properties,
    /// Nodes children.
    pub children: Vec<Node>,
}

/// Node type.
#[derive(Default, Debug, Clone)]
pub enum Type {
    /// Standard Node
    #[default]
    Standard,
    /// Separator Node
    Separator,
    /// Vendor specific Node
    Vendor(String, String),
}

/// Toggle type for toggle-able nodes
#[derive(Default, Debug, Clone, Copy)]
pub enum ToggleType {
    /// Not a toggle.
    #[default]
    None,
    /// Radio item.
    Radio,
    /// CheckMark item.
    Checkmark,
}

/// [`Node`]'s properties.
#[derive(Default, Clone, Debug, zvariant::DeserializeDict)]
pub struct Properties {
    #[zvariant(rename = "type")]
    type_: Option<String>,
    label: Option<String>,
    enabled: Option<bool>,
    visible: Option<bool>,
    #[zvariant(rename = "icon-name")]
    icon_name: Option<String>,
    #[zvariant(rename = "icon-data")]
    icon_data: Option<Vec<u8>>,
    #[zvariant(rename = "toggle-type")]
    toggle_type: Option<String>,
    #[zvariant(rename = "toggle-state")]
    toggle_state: Option<i32>,
    #[zvariant(rename = "children-display")]
    children_display: Option<String>,
}

impl Node {
    /// Gets the node id.
    pub fn id(&self) -> i32 {
        self.id
    }

    /// Gets the node properties.
    pub fn properties(&self) -> &Properties {
        &self.props
    }

    /// Gets the node [`Type`].
    pub fn type_(&self) -> Type {
        self.props.type_()
    }

    /// Gets the node [`ToggleType`].
    pub fn toggle_type(&self) -> ToggleType {
        self.props.toggle_type()
    }

    /// Check if the node is toggled.
    pub fn is_toggled(&self) -> bool {
        self.props.toggle_state().unwrap_or(false)
    }

    /// Gets the node label.
    pub fn label(&self) -> &str {
        self.props.label()
    }

    /// Checks if the node is a submenu.
    pub fn is_submenu(&self) -> bool {
        self.props.children_display() == "submenu"
    }

    /// Checks if the node is enabled.
    pub fn is_enabled(&self) -> bool {
        self.props.enabled()
    }

    /// Checks if the node should be displayed.
    pub fn is_visible(&self) -> bool {
        self.props.visible()
    }

    /// Gets the node's children.
    pub fn children(&self) -> &Vec<Node> {
        &self.children
    }
}

impl Properties {
    /// Gets the node [`Type`].
    pub fn type_(&self) -> Type {
        self.type_.as_deref().map(From::from).unwrap_or_default()
    }

    /// Gets the node label.
    pub fn label(&self) -> &str {
        self.label.as_deref().unwrap_or_default()
    }

    /// Checks if the node is enabled.
    pub fn enabled(&self) -> bool {
        self.enabled.unwrap_or(true)
    }

    /// Checks if the node should be displayed.
    pub fn visible(&self) -> bool {
        self.visible.unwrap_or(true)
    }

    pub fn icon_name(&self) -> Option<String> {
        self.icon_name.clone().filter(|s| !s.is_empty())
    }

    pub fn icon_data(&self) -> Option<Vec<u8>> {
        self.icon_data.clone()
    }

    /// Gets the node [`ToggleType`].
    pub fn toggle_type(&self) -> ToggleType {
        self.toggle_type
            .as_deref()
            .map(From::from)
            .unwrap_or_default()
    }

    /// Gets the toggle state, if applicable.
    pub fn toggle_state(&self) -> Option<bool> {
        match self.toggle_state.as_ref() {
            Some(0) => Some(false),
            Some(1) => Some(true),
            _ => None,
        }
    }

    /// If the node is a submenu, this value is "submenu".
    pub fn children_display(&self) -> &str {
        self.children_display.as_deref().unwrap_or_default()
    }
}

impl<'a> serde::Deserialize<'a> for Node {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'a>,
    {
        let (id, props, children) =
            <(i32, Properties, Vec<(zvariant::Signature, Self)>)>::deserialize(deserializer)?;

        Ok(Self {
            id,
            props,
            children: children.into_iter().map(|c| c.1).collect(),
        })
    }
}

impl zvariant::Type for Node {
    const SIGNATURE: &'static zvariant::Signature =
        <(i32, HashMap<String, zvariant::Value>, Vec<zvariant::Value>)>::SIGNATURE;
}

impl zvariant::Type for Properties {
    const SIGNATURE: &zvariant::Signature = <HashMap<String, zvariant::Value>>::SIGNATURE;
}

impl From<&str> for Type {
    fn from(value: &str) -> Self {
        let ret = match value {
            "separator" => Some(Self::Separator),
            "standard" => Some(Self::Standard),
            _ if value.starts_with("x-") => {
                let value = value.strip_prefix("x-").unwrap();

                if let Some((vendor, type_)) = value.split_once("-") {
                    Some(Self::Vendor(vendor.to_owned(), type_.to_owned()))
                } else {
                    None
                }
            }
            _ => None,
        };

        if let Some(ret) = ret {
            ret
        } else {
            tracing::warn!("Invalid type: {value}. Assuming standard");
            Self::Standard
        }
    }
}

impl From<&str> for ToggleType {
    fn from(value: &str) -> Self {
        match value {
            "radio" => Self::Radio,
            "checkmark" => Self::Checkmark,
            "" => Self::None,
            _ => {
                tracing::warn!("Invalid toggle-type: {value}. Assuming none");
                Self::None
            }
        }
    }
}
