# Shared instrument design

The mixer, network, power, notifications, controls, calendar, session menu, application launcher and settings use `HyprInstrumentHeader` for their top-left icon and title. It composes `HyprPanelHeader`, with one Inter title size and tracking, a consistent icon slot and optional supporting text and trailing controls. `HyprInstrumentText` owns title, body and metadata roles; the notification rows use the same roles with a larger primary message.

`HyprInstrumentColors` owns the charcoal glass gradient, outline and foreground palette. Both `HyprInstrumentSurface` and the general `HyprPopoverSurface` use that material. `HyprPopoverPanel` adds layout constraints and padding without a second opaque wash. The existing superellipse clip and frame share their corner geometry. Hyprland supplies desktop backdrop blur; Widgetbook displays the same translucent fills over its preview backdrop. Section fills remain distinct and translucent. The console caption roles also use the common condensed face and brighter foreground palette, including smaller captions on narrow control pads.

Notifications use colored source badges, outlined message rows, an unread subtitle and explicit dismissal. The backend currently supplies application names rather than application icons or activation actions, so badges use semantic symbols and rows keep a dismiss button. Empty, loading and DND messages use the same translucent row fill and shared body/metadata typography instead of a black recess. Clear all remains disabled when no entries exist; unavailable, loading, DND and overflow states retain their existing behavior.

Controls keep the settings action visible while their groups scroll on short displays. The launcher results pane shrinks below its preferred height when the shared header or an error message needs room.

Widgetbook renders the production widgets directly. The Notifications reference story supplies the three-message composition, while Building blocks / Surfaces / HyprInstrumentHeader exposes the common header and text roles for future panels. Contextual tray menus keep their existing content hierarchy while inheriting the shared popover material.
