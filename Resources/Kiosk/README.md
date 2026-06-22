# ALTN Sign-In — Kiosk Lock (Autonomous Single App Mode)

This locks each iPad to the Sign-In app so customers can't reach Safari, Mail,
Messages, Control Center, the app switcher, or any other app.

The app already contains the kiosk controller (`KioskMode.swift`). It calls
`UIAccessibility.requestGuidedAccessSession(enabled:)`. For that call to actually
engage, two **device-side** prerequisites must be met per iPad:

1. The iPad is **supervised**.
2. A profile whitelists this app's bundle id (`cloud.altn.customer-signin`) for
   Autonomous Single App Mode — that's `ALTN-Kiosk-ASAM.mobileconfig` in this
   folder (Restrictions payload key `autonomousSingleAppModePermittedAppIDs`).

> On a non-supervised iPad (e.g. a personal device running a TestFlight build),
> the lock call simply fails silently — the app still works, it just won't lock.
> So the feature is safe to ship enabled.

## One-time setup per iPad (Apple Configurator)

You need a Mac with **Apple Configurator** (free, Mac App Store) and a USB cable.

1. **Supervise the iPad.** In Apple Configurator: connect the iPad → *Prepare*.
   - Erase + supervise (Manual enrollment is fine; no MDM server required).
   - Optionally set it to auto-launch and hide other apps via a Home Screen layout.
2. **Install the ASAM profile.** Drag `ALTN-Kiosk-ASAM.mobileconfig` onto the
   connected iPad in Apple Configurator (or AirDrop it and install via Settings →
   General → VPN & Device Management). The profile is unsigned — Configurator will
   sign it on install; that's expected.
3. **Install the Sign-In app** (TestFlight or via Configurator).

## Turn the lock on (once per iPad, in the app)

1. Open the Sign-In app, pick the store.
2. Tap the **store-number chip** (top-right) → **Kiosk Lock** → *Manage kiosk lock…*
3. Enter the staff PIN (default **`0035`**) and turn **Lock iPad to this app** ON.
   Change the PIN from the same screen.

From then on the iPad re-locks automatically on every launch / wake.

## Staff exit (to leave the app)

Tap the store chip → **Kiosk Lock** → *Manage kiosk lock…* → enter PIN →
**Exit lock & leave app**. The lock releases so you can press Home. When the
Sign-In app is reopened it re-locks itself automatically.

## If you later adopt an MDM (Jamf, Mosyle, etc.)

Instead of the .mobileconfig + Configurator, push the same Restrictions setting
(`autonomousSingleAppModePermittedAppIDs = cloud.altn.customer-signin`) from the
MDM to all kiosk iPads over the air. The app code is unchanged.
