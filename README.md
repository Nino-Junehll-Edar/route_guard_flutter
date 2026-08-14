# RouteGuard

RouteGuard is a Flutter-based mobile and web application designed for community-driven hazard reporting and navigation. It allows users to report, confirm, and navigate around road hazards while providing agencies with tools to publish official advisories. The application has been migrated from Firebase to Supabase to eliminate ongoing costs while maintaining identical functionality.

## FEATURES

- **User Authentication**: Email/password sign up/sign in via Supabase Auth
- **Hazard Reporting**: Users can report hazards with photos, location, and description
- **Real-time Updates**: Live hazard updates via Supabase Realtime
- **Community Validation**: Users can confirm/deny hazards to improve accuracy
- **Reputation System**: Users earn/lose reputation based on validation accuracy
- **Hazard Status Calculation**: Automatic status determination (clear/partial/uncertain/impassable) based on confidence scores
- **Time-based Decay**: Hazard confidence decays over time based on hazard type
- **Proximity Notifications**: Alerts when users are near active hazards
- **A* Pathfinding**: Hazard-aware routing algorithm for navigation
- **Agency Dashboard**: Official agencies can publish advisories and manage requests
- **Offline-first Caching**: Report hazards while offline, sync when connectivity restored
- **Performance Monitoring**: Instrumentation to track operation durations

## PLATFORM SUPPORT

- Mobile: Android & iOS (Flutter)
- Web: Responsive Flutter web application (Agency Dashboard)
- Backend: Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions)

## TECHNICAL STACK

- **Frontend**: Flutter/Dart ^3.12.2 (mobile app) + Flutter/Dart ^3.12.2 (agency web dashboard)
- **Backend**: Supabase (PostgreSQL + Auth + Storage + Realtime + Edge Functions) ^1.10.0
- **State Management**: Service Locator Pattern
- **Database**: PostgreSQL with PostGIS extension for geographic queries
- **Storage**: Supabase Storage for hazard photos ^1.10.0
- **Real-time**: Supabase Realtime for live hazard updates ^1.10.0
- **Authentication**: Supabase Auth (email/password) ^1.10.0
- **Security**: Row Level Security (RLS) on all tables ^1.10.0
- **Offline-first**: SharedPreferences caching with automatic sync ^2.2.2

## DEPENDENCIES & VERSIONS

- **Flutter SDK**: ^3.12.2
- **Supabase Flutter**: ^1.10.0
- **Supabase JS**: ^1.10.0
- **Flutter Map**: ^8.3.1
- **LatLong2**: ^0.10.1
- **Google Fonts**: ^4.0.5
- **Flutter SVG**: ^2.0.7
- **Intl**: ^0.17.0
- **Dio**: ^5.4.0
- **Flutter Polyline Points**: ^3.1.0
- **Flutter Launcher Icons**: ^0.13.1
- **Shared Preferences**: ^2.2.2
- **Connectivity Plus**: ^5.0.2
- **Geolocator**: ^9.0.2
- **Firebase Messaging**: ^14.0.4
- **Flutter Local Notifications**: ^9.6.6
- **Flutter Lint** (dev): ^6.0.0

## Project Structure

```
route_guard/
├── lib/
│   ├── main.dart                  # App entry point
│   ├── models/                    # Data models
│   │   ├── hazard.dart            # Hazard model with status calculation
│   │   └── user.dart              # UserProfile model with reputation/level
│   ├── screens/                   # UI screens
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   ├── map_screen.dart        # Interactive map with hazard visualization
│   │   ├── profile_screen.dart    # User reputation, level, progress
│   │   └── web/                   # Agency web dashboard
│   │       ├── dashboard_screen.dart
│   │       └── request_access_screen.dart
│   ├── services/                  # Business logic services
│   │   ├── auth_service.dart              # Supabase authentication
│   │   ├── database_service.dart          # Direct Supabase operations
│   │   ├── storage_service.dart           # Hazard photo uploads/deletes
│   │   ├── realtime_hazard_service.dart   # Live hazard updates
│   │   ├── location_service.dart          # GPS location handling
│   │   ├── notification_service.dart      # Firebase/local notifications
│   │   ├── proximity_notification_service.dart # Hazard proximity alerts
│   │   ├── synchronized_database_service.dart # Offline-first caching + sync
│   │   ├── local_cache_service.dart       # SharedPreferences caching
│   │   ├── connectivity_service.dart      # Internet connectivity monitoring
│   │   ├── performance_monitoring_service.dart # Operation timing/metrics
│   │   └── service_locator.dart           # Dependency injection container
│   ├── routing/                   # Navigation algorithms
│   │   ├── astar.dart             # A* pathfinding implementation
│   │   └── route_calculator.dart  # Route calculation service
│   └── supabase_options.dart      # Supabase configuration (gitignored)
├── supabase/
│   ├── schema.sql                 # Database schema with RLS policies
│   └── functions/                 # Supabase Edge Functions
│       ├── reputationAlgorithm/   # Updates reputation & hazard confidence
│       ├── timeDecay/             # Applies time-based confidence decay
│       └── hazardStatus/          # Determines hazard status from votes
├── test/                          # Widget tests
├── web/                           # Flutter web assets
└── documentation/
    ├── TESTING_GUIDE.md           # Comprehensive testing instructions
    └── PROJECT_OVERVIEW.md        # Detailed architecture overview
```

## SETUP INSTRUCTIONS

### Prerequisites
- Flutter SDK installed
- Supabase account and project created
- Optional: Android Studio/Xcode for device testing

### Setup Steps

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd route_guard
   ```

2. **Get Flutter Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Copy the example configuration file:
     ```bash
     cp lib/supabase_options.example.dart lib/supabase_options.dart
     ```
   - Edit `lib/supabase_options.dart` with your actual Supabase URL and anon key
   - Apply `supabase/schema.sql` to your Supabase project
   - Create storage bucket 'hazard-photos' (public)
   - Deploy edge functions: `supabase functions deploy`
   - Configure edge function environment variables

4. **Run the App**
   ```bash
   flutter run          # For device/emulator
   flutter run -d chrome # For web testing
   ```

### Environment Variables

For Supabase Edge Functions, create `.env` files in the function directories as needed:
```
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

Note: All environment files are gitignored for security.

## TESTING

See `TESTING_GUIDE.md` for comprehensive instructions on:
- Setting up and testing Supabase schema
- Deploying and testing edge functions
- Testing on Android devices (including offline scenarios)
- Testing on web browsers
- Common test scenarios and security testing
- Performance monitoring usage
- Troubleshooting common issues

Run widget tests:
```bash
flutter test
```

## DOCUMENTATION

- [PROJECT_OVERVIEW.md](documentation/PROJECT_OVERVIEW.md) - Detailed architecture and implementation
- [TESTING_GUIDE.md](documentation/TESTING_GUIDE.md) - Testing instructions and best practices
- [SECURITY_REVIEW.md](documentation/SECURITY_REVIEW.md) - Security configuration review
- [NEXT_STEPS.md](documentation/NEXT_STEPS.md) - Planned features and remaining work
- [DETAILED_CHECKLIST.md](documentation/DETAILED_CHECKLIST.md) - Detailed task breakdown with completion tracking

## SECURITY

- Row Level Security enforced at database level
- Input validation through parameterized queries
- Secure storage in Supabase Storage
- API keys: Anon key in client (standard Supabase practice), service key only in edge functions
- Permission scoping: Location and notification permissions requested at runtime
- Error handling: Graceful degradation when services unavailable

## FUTURE ENHANCEMENTS

See [NEXT_STEPS.md](NEXT_STEPS.md) for detailed roadmap, including:
- Reputation-weighted voting
- Geographic clustering of hazard reports
- Advanced routing with traffic data
- Online/Offline symbology indicators
- Advanced filtering options
- Multilingual support
- Accessibility improvements
- Analytics integration

## CONTRIBUTING

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing-feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## DEVELOPMENT WORKFLOW

We follow a task-based commit strategy:
- **Per Task**: Commit and push changes related to each specific task (1-15) separately
- **Per Folder**: Group related changes by modified folders when appropriate
- **Clear Messages**: Use descriptive commit messages referencing the task number and description
- **Example**: `git commit -m "Task 10: Complete agency dashboard screen implementation"`

See [NEXT_STEPS.md](NEXT_STEPS.md) for detailed task breakdown and status tracking.

## LICENSE

This project is licensed under the MIT License - see the LICENSE file for details.

## ACKNOWLEDGEMENTS

- Flutter team for the amazing cross-platform framework
- Supabase team for the open-source Firebase alternative
- The open-source community for various packages and plugins used