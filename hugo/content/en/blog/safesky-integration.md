---
title: "SafeSky Integration: Real-Time Traffic Awareness in CaptainVFR"
date: 2025-08-23T08:00:00+02:00
draft: false
description: "Discover how CaptainVFR integrates with SafeSky to provide real-time aircraft traffic awareness, collision warnings, and enhanced flight safety for VFR pilots."
featured_image: "/images/screenshots/safesky-integration.jpg"
tags: ["SafeSky", "Traffic", "Safety", "Features", "Real-time"]
categories: ["Features", "Safety"]
author: "CaptainVFR Team"
---

We're excited to announce the integration of **SafeSky** real-time traffic awareness into CaptainVFR! This powerful feature brings live aircraft tracking directly to your flight planning and navigation app, significantly enhancing situational awareness and flight safety.

{{< figure src="/images/screenshots/safesky-integration.jpg" alt="SafeSky integration in CaptainVFR showing real-time aircraft traffic" caption="Real-time aircraft traffic displayed on CaptainVFR's map with SafeSky integration" >}}

## What is SafeSky?

[SafeSky](https://www.safesky.app) is a revolutionary traffic awareness platform that aggregates real-time aircraft position data from over 30 different sources. It creates a comprehensive picture of air traffic by combining:

- **ADS-B and Mode-S** transponder data
- **FLARM** glider and light aircraft tracking
- **FANET** paraglider and hang glider beacons
- **OGN** (Open Glider Network) trackers
- **PilotAware** and other electronic conspicuity devices
- **Mobile app users** sharing their GPS position
- **UAV/Drone** tracking systems

This multi-source approach means you'll see traffic that single-system receivers might miss, from commercial jets to paragliders, all in one unified view.

## How SafeSky Works in CaptainVFR

The SafeSky integration operates seamlessly through our secure backend proxy, ensuring your API keys remain protected while delivering real-time traffic data directly to your device. The system:

1. **Fetches live beacon data** every 5 seconds for your current map viewport
2. **Filters and processes** traffic information based on relevance and proximity
3. **Displays aircraft** with appropriate icons, headings, and altitude information
4. **Calculates collision risks** using advanced path prediction algorithms
5. **Shows only airborne traffic** to reduce clutter at airports

## Key Features

### 🎯 Intelligent Collision Detection

Our implementation goes beyond simple proximity warnings. The system:
- Calculates actual **flight path convergence** using velocity vectors
- Predicts the **Closest Point of Approach (CPA)** between aircraft
- Shows red warning circles **only for genuine collision risks**
- Considers altitude separation (±1000 feet)
- Alerts for conflicts within 15 minutes and 2km horizontal separation

### 📍 Smart Traffic Display

- **Aircraft icons** rotate to show actual heading/course
- **Altitude-based transparency** - aircraft far above or below fade out
- **Callsign labels** for aircraft within 50km
- **Color-coded by aircraft type** (jets, helicopters, gliders, etc.)
- **Altitude badges** showing flight level at a glance

### 🔄 Automatic State Persistence

Your SafeSky layer preference is automatically saved. When you restart CaptainVFR, the traffic layer will be in the same state you left it, ready to provide immediate awareness.

## How to Activate SafeSky in CaptainVFR

Activating the SafeSky traffic layer is simple:

1. **Open the Menu** - Tap the menu icon (☰) in the top-right corner
2. **Find Map Layers** section in the menu
3. **Toggle SafeSky** - Tap the SafeSky button to enable/disable the traffic layer
4. **View Traffic** - Aircraft will appear on your map with appropriate icons and labels

The toggle button will turn blue when active, and the layer state is automatically saved for your next session.

## Understanding the Display

When SafeSky is active, you'll see:

- **Aircraft Icons** - Different shapes for different aircraft types
- **Heading Indicators** - Icons rotate to show direction of travel
- **Altitude Labels** - Small badges showing altitude in feet
- **Callsigns** - Displayed for nearby aircraft (within 50km)
- **Warning Circles** - Red rings around aircraft on collision course
- **Color Coding**:
  - Blue: Powered aircraft
  - Orange: Helicopters
  - Cyan: Gliders
  - Green: Paragliders
  - Purple: Drones
  - Red: Military or collision threats

## Safety Considerations

While SafeSky significantly enhances situational awareness, remember:

- **Not all aircraft are visible** - Some may not have detection devices
- **Coverage varies** - Ground station availability affects detection
- **VFR principles apply** - Always maintain visual separation
- **Supplement, don't replace** - Use alongside traditional collision avoidance
- **Internet required** - The feature needs data connectivity to function

## Premium Features

The SafeSky integration in CaptainVFR includes:

- ✅ Real-time traffic display
- ✅ Collision risk assessment
- ✅ Multi-source traffic aggregation
- ✅ Automatic refresh every 5 seconds
- ✅ Smart rate limiting to prevent overuse
- ✅ Secure API key management

## Technical Implementation

Our SafeSky integration features:

- **Secure proxy backend** protecting your API credentials
- **Intelligent caching** reducing unnecessary API calls
- **Rate limiting** with exponential backoff
- **Viewport-based loading** for optimal performance
- **Real-time streaming** updates via WebSocket-like connections

## Getting Started

To start using SafeSky in CaptainVFR:

1. Ensure you have an active internet connection
2. Enable location services for CaptainVFR
3. Toggle the SafeSky layer from the menu
4. Watch as real-time traffic appears on your map

## Conclusion

The SafeSky integration represents a significant step forward in making VFR flying safer and more informed. By combining CaptainVFR's comprehensive flight planning tools with SafeSky's extensive traffic network, pilots gain unprecedented situational awareness.

Whether you're navigating busy airspace, avoiding glider areas, or simply wanting to know what's around you, SafeSky in CaptainVFR provides the real-time information you need to make informed decisions.

Stay safe, stay informed, and enjoy the enhanced awareness that SafeSky brings to your flights!

---

*Note: SafeSky is designed to supplement, not replace, proper lookout and collision avoidance procedures. Always follow VFR principles and maintain visual separation from other aircraft.*