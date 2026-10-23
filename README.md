# Laundry Management App

A comprehensive Flutter-based solution for managing laundry businesses, catering to both owners and customers. This application simplifies the process of tracking machines, managing payments, and engaging customers through loyalty programs.

## Features

### For Customers
-   **Machine Booking & Status**: View available washers and dryers, check their status (Available, Busy, Reserved, Maintenance) in real-time, and reserve machines.
-   **Loyalty Program**: Earn points for every transaction, track point history, and redeem rewards or vouchers.
-   **Interactive Dashboard**: Easy access to active machines, promotions, and nearby laundry outlets.
-   **Promotions**: View and apply manual or auto-promotions to save on laundry costs.
-   **Flexible Payments**: Multiple payment options supported for convenient transactions.
-   **Report Issues**: Easily report machine breakdowns or issues directly from the app.

### For Business Owners
-   **Business Dashboard**: Get a birds-eye view of your laundry business performance with `analysis_dashboard.dart`.
-   **Machine Management**: functionality to add, remove, or update washing machines and dryers (`manage_laundry.dart`).
-   **Revenue Reports**: Detailed reports on earnings, reservations, and customer usage (`owner_reports_page.dart`).
-   **Promotion Management**: Create and manage manual and automatic promotions to drive sales.
-   **Laundry Profile**: Customize laundry shop details, opening hours, and location.

## Technology Stack

-   **Frontend**: [Flutter](https://flutter.dev/) (Dart)
-   **Backend**: [Firebase](https://firebase.google.com/)
    -   **Authentication**: Secure user login and registration (`firebase_auth`).
    -   **Cloud Firestore**: Real-time database for storing user data, machine states, and transaction history (`cloud_firestore`).
-   **Visualization**: [fl_chart](https://pub.dev/packages/fl_chart) for analytics and reporting graphs.
-   **State Management**: Native Flutter state management.

## Getting Started

### Prerequisites

-   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version 3.0.0 or higher)
-   [Dart SDK](https://dart.dev/get-dart)
-   A Firebase project configured for this app.

### Installation

1.  **Clone the repository**
    ```bash
    git clone https://github.com/yourusername/laundry_app.git
    cd laundry_app
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration**
    -   Ensure `firebase_options.dart` is present in `lib/`. If not, configure it using the FlutterFire CLI:
        ```bash
        flutterfire configure
        ```

4.  **Run the App**
    ```bash
    flutter run
    ```

## Project Structure

The project follows a standard Flutter directory structure:

-   `lib/main.dart`: Entry point of the application.
-   `lib/pages/`: Contains all the UI screens (e.g., `login_page.dart`, `user_home.dart`, `owner_home.dart`).
-   `lib/models/`: Data models for Points, Reports, Rewards, etc.
-   `lib/widgets/`: Reusable UI components.
-   `lib/theme/`: App theming and styling configurations.

## License

[MIT License](LICENSE)
