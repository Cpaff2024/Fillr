# Fillr (iOS App)

## Description

Fillr is a SwiftUI-based iOS application designed to help users find and add free water refill stations. The app aims to reduce single-use plastic bottle consumption by making it easy to locate places where users can refill their reusable water bottles. It includes features for mapping stations, user authentication, adding new stations (including drafts), logging personal refills, and tracking environmental impact through gamification elements like badges.

## Features

* **Map View:** Displays nearby water refill stations on an Apple MapKit map.
* **Station Details:** View information about a specific station, including name, type, cost, limitations, photos, user reviews, and directions.
* **Add Station:** Users can add new stations.
    * Supports adding based on current location ("Here Now") with photo uploads.
    * Supports saving stations as local drafts with address/description for later completion.
* **User Authentication:** Secure user sign-up, login, sign-out, and password reset using Firebase Authentication.
* **User Profiles:** Displays user information, profile picture, contribution stats (stations added), personal impact stats (bottles/CO₂ saved based on refills), and earned badges.
* **Personal Refill Logging:** Users can log when they refill their bottle at a station, contributing to their personal impact metrics.
* **Draft Management:** Users can view and manage their locally saved draft stations.
* **Favorites:** Users can mark stations as favorites.
* **Reviews:** Users can read and write reviews for stations.
* **Filtering:** Filter stations on the map based on type and cost.
* **Gamification:** Basic badge system based on user contributions (stations added, refills logged).

## Technology Stack

* **UI Framework:** SwiftUI
* **Mapping:** Apple MapKit
* **Backend & Database:** Firebase
    * Authentication: Firebase Authentication
    * Database: Firestore (for station data, user profiles, reviews)
    * Storage: Firebase Cloud Storage (for station photos, user profile pictures)
* **Location:** CoreLocation
* **Concurrency:** Combine (for map location debouncer), async/await
* **Dependency Management:** Swift Package Manager (SPM)
* **Local Storage:** UserDefaults (for drafts, App Settings)

## Setup Instructions

1.  **Clone Repository:** `git clone <repository-url>`
2.  **Open Project:** Open the `.xcodeproj` file in Xcode.
3.  **Firebase Configuration:**
    * You will need a Firebase project set up.
    * Download the `GoogleService-Info.plist` file from your Firebase project settings.
    * Place the `GoogleService-Info.plist` file into the main project directory in Xcode, ensuring it's added to the `Fillr` target membership.
4.  **Swift Packages:** Xcode should automatically resolve Swift Package Manager dependencies. If you encounter issues, try `File > Packages > Reset Package Caches` or `File > Packages > Resolve Package Versions`.
5.  **Build & Run:** Select a simulator or physical device and run the app (Cmd+R).
