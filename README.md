# AROVA 🚑🏥
**Emergency Response & Hospital Dispatch Network**

AROVA connects ambulances to hospitals in real-time. Using voice-to-text and live routing, it matches emergencies to the nearest facility to save lives.

## 🚀 The Problem
During critical emergencies, transit delays and miscommunication between paramedics and receiving hospitals cost valuable time. Ambulances often arrive at hospitals that are ill-equipped or lack available beds for specific traumas, leading to fatal delays.

## 💡 The Solution
AROVA bridges the gap between first responders and medical facilities. It allows paramedics to instantly broadcast patient conditions via voice-to-text and uses a smart matching system to ping the nearest hospitals. Once a hospital accepts, AROVA generates a live route to minimize transit time.

## ✨ Key Features
* **Role-Based Portals:** Dedicated interfaces for Ambulance Drivers (Broadcasting) and Hospital Dashboards (Receiving).
* **Voice-to-Text Diagnostics:** Hands-free symptom reporting using integrated device microphones.
* **Live Open-Source Routing:** Real-time distance calculation and map drawing using OpenStreetMap and OSRM (Open Source Routing Machine).
* **Smart Dispatch System:** Broadcasts emergency requests with exact GPS coordinates to hospitals within a dynamic radius.
* **Trip History & Analytics:** Persistent logging of completed emergency runs for accountability.
* **Simulated OTP Authentication:** Secure login and registration flow.

## 🛠️ Tech Stack
* **Frontend:** Flutter & Dart
* **Backend:** Firebase (Firestore NoSQL Database)
* **Maps & Routing:** `flutter_map`, OpenStreetMap tiles, OSRM API
* **Hardware Integrations:** `geolocator` (GPS), `speech_to_text` (Microphone), `image_picker` (Camera/Gallery)

## 📱 How to Run Locally

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/Brahmani-reddy/Arova_app.git](https://github.com/Brahmani-reddy
   /Arova_app.git).
