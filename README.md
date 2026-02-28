# KitaHack Disaster Management System

A real-time disaster management and response application designed to connect citizens, rescuers, and authorities. Built for the KitaHack Hackathon.

---

## 🚀 System Overview
KitaHack enables rapid reporting of incidents, visualizes disaster trends, provides safety check-in mechanisms, and automates disaster identification using Artificial Intelligence.

# City Guard — Real-Time Disaster Management & Safety Guidance System

City Guard is a real-time disaster management and response mobile application built with **Flutter + Firebase + Google Maps Platform**, enhanced with **Google Gemini** to transform raw citizen reports into actionable disaster intelligence. It connects **citizens, rescuers, and authorities** through incident reporting, SOS dispatch, safety check-ins, and AI-assisted shelter navigation.

---

## Table of Contents
- [1. Technical Architecture](#1-technical-architecture)
- [2. Implementation Details](#2-implementation-details)
- [3. Challenges Faced](#3-challenges-faced)
- [4. Future Roadmap](#4-future-roadmap)

---

## 1. Technical Architecture

### Frontend (Flutter App)
The frontend is built with **Flutter** to deliver a high-performance cross-platform mobile experience. City Guard provides role-based screens such as **Home**, **Map**, **Alerts**, **Incident Reporting**, **SOS**, **Safety Check-In**, and **Shelter Navigation**, designed to remain usable in high-stress environments (high contrast UI, simplified actions, one-tap safety updates).

### Backend (Serverless Firebase)
City Guard uses a **Firebase-first serverless architecture**, avoiding the need to maintain a custom server. The app communicates directly with Firebase services for authentication, real-time synchronization, and media storage, enabling instant updates across devices.

### Data Storage / Database
- **Cloud Firestore** stores structured data including users, reported cases, disasters, SOS cases, shelters, and areas.
- **Firebase Cloud Storage** stores incident media (photos/videos), with download URLs linked back into Firestore documents for app rendering.

### AI Technology Used (Google AI)
City Guard integrates **Google Gemini 2.5 Flash** via the **Gemini API** (with structured JSON responses) to act as a *Disaster Management Analyst*. AI converts unstructured citizen reports into:
- consolidated disaster events,
- standardized severity labels,
- one-line summaries,
- trend escalation signals,
- shelter recommendations based on user location + shelter availability.

### Other Google Technologies and Services
- **Google Maps Platform (Maps SDK for Flutter)** for interactive incident visualization (markers / heatmap-style overlays).
- **Geolocation & Reverse Geocoding** for live user location and human-readable place names.
- **Google Routes API** for real-time ETA calculations to shelters, improving routing decisions under traffic constraints.
- **Firebase Authentication** for secure identity + role separation (Citizen vs Rescuer/Admin).
- **Firestore Security Rules** to protect writes/reads across collections.

---

## 2. Implementation Details

### Incident Reporting Lifecycle
1. A user submits an incident report (category, severity, description, GPS location, media).
2. Media is uploaded to **Firebase Storage**, then a `reported_cases` record is created in **Firestore**.
3. **Gemini AI** analyzes the report alongside nearby reports and returns structured JSON.
4. Firestore is updated with:
   - grouped disaster ID / disaster record,
   - standardized severity,
   - one-line summary,
   - alert-ready information.
5. All users in affected areas see updates instantly via Firestore streams.

### SOS Emergency Workflow
- Users trigger SOS via a **3-second hold-to-activate** interaction.
- An SOS record is created in Firestore and progresses through:
  **Sending → Acknowledged → Help Dispatched**
- Rescuers/Admin view SOS events and dispatch responses while the user sees status updates in real time.

### Proactive Safety Check-In
- The app monitors lifecycle events and triggers reminders if users exit during active disasters.
- Users can mark **"I'm Safe"** with one tap, updating their status in Firestore so responders can focus on those unconfirmed.

### AI-Powered Shelter Recommendation + Navigation
1. App fetches the user’s live location and the shelter dataset from Firestore.
2. **Routes API** calculates real-time travel time (ETA) to nearby shelters.
3. **Gemini** ranks shelters using:
   **Travel Time + Shelter Status (Open/Closed) + Capacity (Available/Full)**
4. Users can tap the recommended shelter to navigate via Google Maps.

---

## 3. Challenges Faced

### 1) AI Reliability & Model Evolution
**Challenge:** Early AI responses sometimes failed to return structured data, causing crashes. We also needed to balance speed with intelligence.  
**Solution:** Enforced structured JSON via strict response configuration, migrated models from `gemini-1.5-flash` to optimized **Gemini 2.5 Flash Lite** for faster inference, and implemented fallback logic (heuristic ranking) when AI fails.

### 2) The “Moving Target” of Real-Time Locations
**Challenge:** GPS can be unreliable indoors or on emulators; the app sometimes hung while waiting for a high-accuracy fix.  
**Solution:** Implemented a multi-stage location strategy: **High accuracy → Last known → Low accuracy → Fallback to Kuala Lumpur center**. Added reverse geocoding to ensure user-friendly location names (e.g., “Damansara”).

### 3) Accidental SOS Triggers
**Challenge:** A single tap could cause false alarms, but SOS must still feel instant.  
**Solution:** Built a **3-second hold-to-trigger** mechanism with visible progress feedback and a helpful SnackBar instruction for accidental taps.

### 4) Disaster Information Overload
**Challenge:** High-volume reports (e.g., 50 people reporting the same flood) created map clutter and alert noise.  
**Solution:** Designed a **Gemini-powered grouping service** that clusters raw reports into a single disaster event with unified title, severity, and summary.

### 5) Dynamic Shelter Ranking
**Challenge:** The nearest shelter isn’t always best (it may be “Full” or “Closed”).  
**Solution:** Combined **Routes API ETA** + Gemini reasoning on **status and capacity**, returning both ranking and human-readable explanation (e.g., “20 spots remaining and only 5 minutes away”).

### 6) Schema Migration & Data Consistency
**Challenge:** As the project grew, legacy Firestore naming (e.g., incidents vs reports) created confusion.  
**Solution:** Refactored into a unified `reported_cases` schema and standardized identity linkage using `reporterUid`.

### 7) App Branding & Visual Contrast
**Challenge:** Some UI elements were too thin for outdoor/high-stress usage.  
**Solution:** Improved visibility by increasing slider thickness, thumb size, and strengthening branding with a consistent icon and slogan: **“Your Safety, Our Priority.”**

### 8) Repository Stability & Git Conflicts
**Challenge:** “Unclean working tree” blocked branch switching; some key feature files were overwritten during merges.  
**Solution:** Discarded local changes to auto-generated build artifacts, standardized on `main`, and restored missing feature files to stabilize development.

### 9) Database Schema Case Sensitivity (“Ghost Collections”)
**Challenge:** Some components wrote to `Areas` while others read from `areas`, causing missing/duplicated data.  
**Solution:** Audited references across the codebase and unified everything to lowercase `areas`.

### 10) Bridging Technical IDs with Human Context
**Challenge:** Gemini output used technical Area IDs (e.g., `ALRVLK8...`) which was unreadable for users.  
**Solution:** Implemented a context enrichment step by pre-fetching area names and refining prompts to prioritize human-readable names.

### 11) Android Build Hurdles (Core Library Desugaring)
**Challenge:** Notification plugin caused Gradle errors (`checkDebugAarMetadata`) due to Java 8+ requirements.  
**Solution:** Enabled **Core Library Desugaring** in `build.gradle.kts` with `desugar_jdk_libs` to support modern libraries on older Android versions.

### 12) Notification Lifecycle & Synchronization
**Challenge:** Notifications needed immediate lock-screen visibility but also needed to clear when marked read in-app.  
**Solution:** Built a custom NotificationService with `flutter_local_notifications`, high-priority channels, optional `fullScreenIntent`, and programmatic clearing via “Mark all read.”

### 13) AI Service Continuity & Rate Limits
**Challenge:** Hit rate limits on free Gemini tiers and encountered 404 errors with unreleased model names.  
**Solution:** Stabilized endpoints to supported models and performed controlled migrations to maintain service continuity during testing.

### 14) Resource Synchronization (Missing Shelter Images)
**Challenge:** Shelter navigation showed broken images due to mismatched asset paths.  
**Solution:** Registered the shelter asset directory and synchronized Firestore records to valid local asset paths.

---

## 4. Future Roadmap

### 1) Government & Agency Deployment (Bomba, Police, NADMA, Hospitals)
We aim to evolve City Guard into a deployment-ready platform for Malaysian government agencies (e.g., **Bomba, Police, NADMA, local councils, hospitals**) by introducing:
- Agency-specific dashboards (dispatch queues, incident verification, resource allocation)
- Verified responder accounts and permission tiers
- Integration with official hotlines and command centers

### 2) Verified Shelter & Capacity Feeds
To improve shelter accuracy and real-world usability, City Guard will support verified shelter operations by enabling:
- Real-time shelter capacity updates through official operators
- QR-based check-in/out at shelters to auto-update occupancy
- Offline-first shelter lists during network disruptions

### 3) Multi-Language & Accessibility Hardening
To ensure inclusivity and usability under high-stress conditions, City Guard will expand accessibility by adding:
- Bahasa Malaysia + multilingual support (e.g., EN/ZH/TA)
- WCAG-aligned contrast modes and simplified emergency UX
- Larger “one-tap” emergency actions with haptic confirmations

### 4) Offline-First Emergency Mode
During disasters, internet connectivity can become unstable due to power outages, congestion, or infrastructure damage. City Guard will introduce an Offline-First Emergency Mode that:
- Caches critical safety information on-device (last known disaster alerts, nearby shelters, emergency contacts, and safety instructions)
- Queues incident reports locally and uploads automatically once connectivity is restored
- Ensures users can still make safe decisions even without a live connection

### 5) Family & Group Safety (“Circle” Feature)
To reduce panic and improve coordination among close contacts, City Guard will introduce private safety circles that enable:
- Creation of Family/Friend groups (e.g., parents, siblings, roommates, teammates)
- Real-time safety status sharing: **Safe / Need Help / Unknown**
- Quick actions such as **Share My Location** and **Request Help** for faster coordination and reassurance

---

## License
This project was created for hackathon prototyping and learning purposes. Licensing details can be added here if the repository is made public.
