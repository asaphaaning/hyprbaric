enum LayerShellDropdownAnchor { left, center, right }

enum LayerShellDropdownTransition { reveal, grow }

/// Whether switching to or from a dropdown hands its shell to the other.
///
/// Two [morph] dropdowns opened in place of one another share one glass
/// shell that glides between their frames, while their sections stagger
/// out and in. Any other switch replaces the dropdown instantly.
enum LayerShellDropdownHandoff { none, morph }
