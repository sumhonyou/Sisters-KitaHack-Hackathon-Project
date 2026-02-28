# KitaHack Disaster Management System

A real-time disaster management and response application designed to connect citizens, rescuers, and authorities. Built for the KitaHack Hackathon.

---

## 🚀 System Overview
KitaHack enables rapid reporting of incidents, visualizes disaster trends, provides safety check-in mechanisms, and automates disaster identification using Artificial Intelligence.

## 🤖 Google AI Technology (Gemini)
The system leverages the **Google Gemini Pro** model (specifically `gemini-2.5-flash` integration) to act as a **Disaster Management Analyst**.

### Key AI Features:
- **Intelligent Incident Grouping**: Automatically clusters multiple individual reports into a single "Disaster" event on the map.
- **Automated Summarization**: Generates one-sentence situational overviews for rapid response.
- **Trend Analysis**: Analyzes patterns across geographical areas to identify safe zones or escalation risks.
- **Severity Assessment**: Standardizes severity levels from user descriptions to prioritize critical cases.

## 🛠️ Google Developer Technologies
Built on a robust foundation of industry-leading Google platforms:

- **Firebase Cloud Platform**:
  - **Authentication**: Secure role-based access control.
  - **Cloud Firestore**: Real-time NoSQL database for instant data synchronization.
  - **Cloud Storage**: Secure hosting for incident media and photos.
- **Google Maps Platform**:
  - **Maps SDK for Flutter**: Interactive heatmaps and incident visualization.
  - **Geocoding & Geolocation**: Precise coordinate-to-address translation.

## 🔄 Core System Workflows

### 1. Incident Reporting Lifecycle
1. **Detection**: User captures geo-tagged media and selects a category (Flood, Fire, etc.).
2. **AI Action**: Gemini detects the report and groups it into an active disaster.
3. **Alerting**: All users in the affected area receive a real-time notification on their Alerts dashboard.

### 2. SOS Emergency Workflow
1. **Activation**: Immediate trigger via long-press on the SOS button.
2. **Silent Dispatch**: Precise location and device health (battery/signal) are sent to rescuers.
3. **Response Tracking**: High-contrast dashboard shows: **Sending → Acknowledged → Help Dispatched**.

### 3. Proactive Safety Check-In
1. **Sensing**: App detects if a user exits the app during an active disaster in their area.
2. **Notification**: A nudge is sent to the notification banner.
3. **One-Tap Update**: User marks themselves as "Safe" with a single tap, updating their status for families and rescuers.

## 🏗️ System Architecture
The application follows a **Service-Oriented Architecture (SOA)** built with Flutter:
- **UI Layer**: specialized screens (`HomePage`, `MapPage`, `AlertsPage`) and reusable widgets.
- **Service Layer**: Encapsulated logic for Gemini, Firebase, and Mapping.
- **Model Layer**: Strongly typed entities ensuring data integrity.