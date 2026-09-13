# Motion test drive

Widgetbook → Motion → MotionPlayground → Test drive rehearses three shared
Flutter components: `HyprTextSwap`, `HyprDigitPop`, and `HyprBannerStack`.
They live in `lib/src/widgets/motion`. The bar's active-app title now uses the
same `HyprTextSwap` for its subtitle: switch windows or browser tabs to try the
220 ms transition. The app badge and name update instantly. A new subtitle
interrupting the transition cancels it and appears immediately. In the last
40 ms, the current transition may finish before the latest subtitle appears;
intermediate updates are discarded and never queue another animation.
System reduced motion replaces them immediately. Numbers and notification
stacking remain available in the playground for now.

Build and run from this branch's checkout (release and debug bundles are separate):

```sh
flutter build linux --release
./build/linux/x64/release/bundle/hyprbaric
```

Text and menu swaps use the official `animations` package's fade-through.
Numbers animate changed characters with a short stagger, scale and vertical
translation. Banners retain stable identities as new entries push the older
cards back, with three visible layers and input only on the front card.

Workspace indicators reuse the pop transition in whole-label mode. Their
identity belongs to the visible slot, so cycling beyond the centered range
pops the shifting labels. Selection changes within the same range only update
the highlight. Roman and numeric styles, configurable counts and special names
share this behavior. Widgetbook's interactive WorkspaceStrip story exercises it.

Use Play all, the individual buttons, Slow motion, and Reduced motion to compare
the feel. Normal duration is 220 ms. System reduced motion is honored even when
the demo override is off. Rapid text updates render at most two overlapping
states; values settle to the latest update. Demo timers stop on disposal.

These use opacity and transforms without animated blur filters. The Widgetbook
preview establishes appearance and interaction, not a native FPS guarantee.
Profile on Linux before enabling motion on frequently updated production values.
