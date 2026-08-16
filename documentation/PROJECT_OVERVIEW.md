# RouteGuard Project Overview

## Project Description
RouteGuard is a Flutter-based mobile and web application designed for community-driven hazard reporting and navigation. It allows users to report, confirm, and navigate around road hazards while providing agencies with tools to publish official advisories. The application has been migrated from Firebase to Supabase to eliminate ongoing costs while maintaining identical functionality.

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Key Features](#key-features)
3. [Project Structure](#project-structure)
4. [Data Models](#data-models)
5. [Services](#services)
6. [Supabase Integration](#supabase-integration)
7. [Algorithms](#algorithms)
8. [Offline-First Design](#offline-first-design)
9. [Performance Monitoring](#performance-monitoring)
10. [Testing Guide](#testing-guide)

## Architecture Overview
RouteGuard follows a clean architecture pattern with separation of concerns:
- **Presentation Layer**: UI screens (mobile: login, signup, map, profile; web: agency dashboard, request access)
- **Domain Layer**: Models (Hazard, UserProfile) and business logic (status calculation, reputation system)
- **Data Layer**: Services for authentication, database, storage, realtime updates, location, notifications, and offline synchronization
- **Infrastructure**: Supabase backend (PostgreSQL, Auth, Storage, Realtime, Edge Functions), local caching, connectivity monitoring, service locator

The application uses:
- **Flutter/Dart** for cross-platform UI (mobile & web)
- **Supabase** as backend (PostgreSQL, Auth, Storage, Realtime, Edge Functions)
- **Service Locator Pattern** for centralized dependency injection
- **Offline-first** architecture with synchronization for unreliable connectivity
- **Row Level Security (RLS)** for data protection at the database level
- **Performance Monitoring** instrumentation for tracking operation durations

## Key Features
1. **User Authentication**: Email/password sign up/sign in via Supabase Auth
2. **Hazard Reporting**: Users can report hazards with photos, location, and description
3. **Real-time Updates**: Live hazard updates via Supabase Realtime
4. **Community Validation**: Users can confirm/deny hazards to improve accuracy
5. **Reputation System**: Users earn/lose reputation based on validation accuracy
6. **Hazard Status Calculation**: Automatic status determination (clear/partial/uncertain/impassable) based on confidence scores
7. **Time-based Decay**: Hazard confidence decays over time based on hazard type
8. **Proximity Notifications**: Alerts when users are near active hazards
9. **A* Pathfinding**: Hazard-aware routing algorithm for navigation
10. **Agency Dashboard**: Official agencies can publish advisories and manage requests
11. **Offline-first Caching**: Report hazards while offline, sync when connectivity restored
12. **Performance Monitoring**: Instrumentation to track operation durations

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
│   └── supabase_options.dart      # Supabase configuration
├── supabase/
│   ├── schema.sql                 # Database schema with RLS policies
│   └── functions/                 # Supabase Edge Functions
│       ├── reputationAlgorithm/   # Updates reputation & hazard confidence
│       ├── timeDecay/             # Applies time-based confidence decay
│       └── hazardStatus/          # Determines hazard status from votes
├── test/                          # Widget tests
│   └── widget_test.dart
�└── documentation/
    ├── TESTING_GUIDE.md           # Comprehensive testing instructions
    └── PROJECT_OVERVIEW.md        # This file
```

## Data Models
### UserProfile (lib/models/user.dart)
- `id`: UUID (references auth.users.id)
- `reputation`: Integer (default 0, min 0)
- `email`: String
- `display_name`: String
- `agency`: String (for agency officials)
- `role`: String (user/agency_official)
- `created_at`: Timestamp
- **Methods**: `fromJson()`, `toJson()`, getters for level/progress

### Hazard (lib/models/hazard.dart)
- `id`: UUID (primary key)
- `reporter_uid`: UUID (references auth.users.id)
- `agency_tag`: String
- `location`: GEOGRAPHY(POINT, 4326)
- `hazard_type`: String
- `description`: String
- `photo_url`: String
- `timestamp`: Timestamp
- `confidence`: Integer (0-100, default 50)
- `weighted_confirms`: Decimal (default 0)
- `weighted_denies`: Decimal (default 0)
- `status`: String (`uncertain`, `clear`, `partial`, `impassable`)
- `created_at`: Timestamp
- `updated_at`: Timestamp
- **Key Methods**:
  - `fromJson()`, `toJson()`
  - `calculateStatus()`: Determines status based on confidence
  - `getStatusColor()`: Returns color for map display

## Services
### Core Services
1. **AuthService** (`lib/services/auth_service.dart`)
   - Email/password sign in/sign up
   - Auth state change listener
   - Performance monitored operations

2. **DatabaseService** (`lib/services/database_service.dart`)
   - CRUD operations for user_profiles, hazards, moderation_queue, official_advisories
   - All operations performance monitored
   - Direct Supabase client access

3. **StorageService** (`lib/services/storage_service.dart`)
   - Upload hazard photos to Supabase Storage bucket `hazard-photos`
   - Delete hazard photos
   - Returns public URLs
   - Performance monitored operations

4. **RealtimeHazardService** (`lib/services/realtime_hazard_service.dart`)
   - Subscribes to hazard table changes via Supabase Realtime
   - Returns Stream<List<Hazard>> with optional status filtering
   - Performance monitored stream

5. **LocationService** (`lib/services/location_service.dart`)
   - Gets current position with permission handling
   - Position stream
   - Distance calculation utilities
   - Proximity checking (500m default range)
   - Performance monitored operations

6. **NotificationService** (`lib/services/notification_service.dart`)
   - Firebase Cloud Messaging integration
   - Flutter local notifications for hazard alerts
   - Topic subscription management
   - Performance monitored operations

7. **ProximityNotificationService** (`lib/services/proximity_notification_service.dart`)
   - Monitors user location for nearby active hazards
   - Shows local notifications when within 500m of impassable hazards
   - Prevents duplicate notifications with cooldown period
   - Performance monitored operations

8. **SynchronizedDatabaseService** (`lib/services/synchronized_database_service.dart`)
   - **Offline-first** implementation using:
     - LocalCacheService (SharedPreferences)
     - ConnectivityService (internet monitoring)
     - DatabaseService (Supabase operations)
   - Automatic sync when connectivity changes
   - Manual sync capability (pull-to-refresh)
   - Pending report queue for offline submissions
   - Performance monitored operations

9. **LocalCacheService** (`lib/services/local_cache_service.dart`)
   - Caches hazards and pending reports using SharedPreferences
   - JSON serialization/deserialization of Hazard objects
   - Cache expiration and size limits

10. **ConnectivityService** (`lib/services/connectivity_service.dart`)
    - Monitors internet connectivity changes
    - Stream of boolean connectivity status
    - Uses connectivity_plus package

11. **PerformanceMonitoringService** (`lib/services/performance_monitoring_service.dart`)
    - Singleton service for timing operations
    - Methods: logDuration, logDurationWithResult, logMetric, logCount
    - Mixin available for easy integration
    - Logs to console with "PerformanceMonitoring" tag

### Routing Services
1. **AStar Algorithm** (`lib/services/routing/astar.dart`)
   - Implementation of A* pathfinding algorithm
   - Takes start/end points and hazard locations
   - Returns optimal path avoiding impassable hazards
   - Uses haversine distance for heuristic

2. **RouteCalculator** (`lib/services/routing/route_calculator.dart`)
   - Service that uses A* to calculate routes
   - Gets current hazards from SynchronizedDatabaseService
   - Provides route calculation methods

### Service Locator
**ServiceLocator** (`lib/services/service_locator.dart`)
- Centralized dependency injection
- Lazy initialization of all services
- Single instance access via `ServiceLocator()`
- Initialized in main.dart before app startup

## Supabase Integration

### Database Schema (`supabase/schema.sql`)
**Extensions**:
- `uuid-ossp`: For UUID generation
- `postgis`: For GEOGRAPHY type support (location queries)

**Tables**:
1. **user_profiles**
   - id (UUID, PK, FK to auth.users)
   - reputation (≥0)
   - email, display_name, agency, role
   - created_at
   - RLS: Users can only access their own profile

2. **hazards**
   - id (UUID, PK)
   - reporter_uid (FK to auth.users)
   - agency_tag
   - location (GEOGRAPHY POINT, 4326)
   - hazard_type, description, photo_url
   - timestamp
   - confidence (0-100)
   - weighted_confirms (≥0), weighted_denies (≥0)
   - status (UNCERTAIN/CLEAR/PARTIAL/IMPASSABLE)
   - created_at, updated_at
   - RLS: 
     - Anyone can view
     - Users can only insert/update their own hazards

3. **moderation_queue**
   - id (UUID, PK)
   - hazard_id (FK to hazards)
   - flagged_at, reason
   - reviewed_by (FK to auth.users), reviewed_at
   - outcome (CONFIRMED/FALSE/INCONCLUSIVE)
   - RLS:
     - Users can access only their own hazard's moderation entries
     - Agency officials can access all entries

4. **official_advisories**
   - id (UUID, PK)
   - location (GEOGRAPHY POINT, 4326)
   - hazard_type, description
   - valid_from, valid_until
   - created_at
   - created_by (FK to auth.users)
   - RLS: 
     - Anyone can view
     - Only agency officials can insert/update

**Security**:
- Row Level Security enabled on all tables
- Policies enforce data access restrictions
- Service role key used for edge functions (bypasses RLS for backend logic)

### Edge Functions (`supabase/functions/`)

All functions use:
- Deno runtime
- Supabase JS client with service role key
- Proper error handling and HTTP responses

1. **Reputation Algorithm** (`reputationAlgorithm/index.ts`)
   - **Purpose**: Updates user reputation and hazard confidence based on validation actions
   - **Input**: `{ hazardId, action ("confirm"/"deny"), reporterId }`
   - **Logic**:
     - Fetch hazard and reporter reputation
     - Update reporter reputation: +2 for confirm, -1 for deny (min 0)
     - Update hazard confidence: +10 for confirm, -5 for deny (clamped 0-100)
     - Update weighted confirms/denies counters
     - Determine new status based on confidence thresholds
     - Return success with updated values

2. **Time Decay** (`timeDecay/index.ts`)
   - **Purpose**: Applies time-based confidence decay to prevent stale hazards
   - **Input**: None (processes all applicable hazards)
   - **Logic**:
     - Fetch hazards not in CLEAR/IMPASSABLE status
     - For each hazard:
       - Calculate time elapsed since reporting
       - Get hazard-type specific half-life:
         - Flood: 7 days, Landslide: 14 days, Construction: 3 days, 
         - Accident: 2 days, Weather: 1 day, Default: 10 days
       - Apply decay formula: confidence = 100 × (0.5^(time/half-life))
       - Blend with current confidence (70% decayed, 30% current)
       - Determine new status based on blended confidence
     - Update hazards where status changed
     - Return list of updated hazards

3. **Hazard Status** (`hazardStatus/index.ts`)
   - **Purpose**: Determines hazard status based on confidence and vote ratios
   - **Input**: `{ hazardId }`
   - **Logic**:
     - Fetch hazard
     - Calculate status based on:
       - Confidence ≥80 + more confirms than denies → CLEAR
       - Confidence 60-79 → PARTIAL
       - Confidence 40-59 → UNCERTAIN
       - Else → IMPASSABLE
     - Additional check: If deny ratio >60% AND confidence <70 → IMPASSABLE
     - Update hazard if status changed
     - Return old/new status and vote metrics

## Algorithms

### Confidence Calculation & Status Determination
The hazard validation system uses a scoring mechanism:

1. **Initial State**: New hazards start with confidence=50 (UNCERTAIN)
2. **User Actions**:
   - **Confirm**: +10 confidence, +1 to weighted_confirms
   - **Deny**: -5 confidence, +1 to weighted_denies
3. **Bounds**: Confidence clamped between 0-100
4. **Status Thresholds**:
   - **≥80** and more confirms than denies → CLEAR (green on map)
   - **60-79** → PARTIAL (orange on map)
   - **40-59** → UNCERTAIN (yellow on map)
   - **<40** → IMPASSABLE (red on map)
   - **Special rule**: If >60% denies AND confidence <70 → IMPASSABLE

### Reputation System
- Users earn reputation for accurate validations:
  - +2 for confirming a hazard that gets validated as real
  - -1 for denying a hazard that gets validated as real
  - Inverse applies for incorrect validations (handled via edge function logic)
- Minimum reputation: 0
- Reputation affects user level and map marker credibility

### Time-Based Decay (Hazard Aging)
To prevent hazards from appearing indefinitely:
- Each hazard type has a specific half-life (time for confidence to reduce by 50%)
- Formula: `current_confidence = 100 * (0.5^(elapsed_time / half_life))`
- Blended with actual confidence to prevent abrupt changes: 
  `new_confidence = 0.7 * decayed_confidence + 0.3 * current_confidence`
- Hazard types and half-lives:
  - Flood: 7 days (water recedes relatively quickly)
  - Landslide: 14 days (debris takes time to clear)
  - Construction: 3 days (projects often complete quickly)
  - Accident: 2 days (usually cleared same day)
  - Weather: 1 day (conditions change rapidly)
  - Default: 10 days (for unknown types)

### A* Pathfinding Algorithm
For hazard-aware navigation:
1. **Graph**: Nodes are latitude/longitude points
2. **Heuristic**: Haversine distance (great-circle distance)
3. **Cost Function**: 
   - Base cost: distance between points
   - Hazard penalty: Additional cost for segments near hazards
   - Impassable hazard: Infinite cost (avoided completely)
   - Partial hazard: Moderate penalty
   - Uncertain/Clear hazard: Minimal/no penalty
4. **Output**: Optimal path avoiding high-risk areas

## Offline-First Design
RouteGuard implements a robust offline-first architecture:

### Problem Statement
Users may lose connectivity while reporting hazards in remote areas with poor cell coverage.

### Solution
1. **Local Caching**:
   - Recently viewed hazards cached locally
   - Pending hazard reports stored when offline
   - Using SharedPreferences with JSON serialization

2. **Sync Mechanism**:
   - ConnectivityService monitors internet status
   - When ONLINE → OFFLINE: No action (read from cache)
   - When OFFLINE → ONLINE: 
     - Sync pending reports to Supabase
     - Refresh local cache from server
   - Manual sync available via pull-to-refresh

3. **Conflict Resolution**:
   - Server wins for hazard data (last write wins)
   - Local pending reports are cleared only after successful server insertion
   - Failed reports remain in queue for retry

4. **User Experience**:
   - Users can report hazards offline immediately
   - Visual indicators show offline/online status
   - Pending sync count displayed
   - Automatic background sync when connectivity returns

## Performance Monitoring
All major service operations are instrumented for performance tracking:

### Implementation
- **PerformanceMonitoringService**: Singleton with methods:
  - `logDuration(String operation, Future<void> action())`
  - `logDurationWithResult<T>(String operation, Future<T> action())`
  - `logMetric(String metric, double value, {String unit = ''})`
  - `logCount(String metric, int count)`
- **Mixin**: `PerformanceMonitoringMixin` provides easy access
- **Usage**: Wrapped around database, storage, auth, location, and notification operations

### Metrics Tracked
- Operation durations (e.g., "GetCurrentPosition", "UploadHazardPhoto")
- Custom metrics (e.g., error counts, sync operations)
- All logged with "PerformanceMonitoring" tag for easy filtering

### Benefits
- Identify bottlenecks in real-world usage
- Verify performance optimizations
- Provide data for continuous improvement
- Help debug user-reported slowness issues

## Testing Guide
See `TESTING_GUIDE.md` for comprehensive instructions on:
- Setting up and testing Supabase schema
- Deploying and testing edge functions
- Testing on Android devices (including offline scenarios)
- Testing on web browsers
- Common test scenarios and security testing
- Performance monitoring usage
- Troubleshooting common issues

## Getting Started for Developers
1. **Prerequisites**:
   - Flutter SDK installed
   - Supabase account and project created
   - Optional: Android Studio/Xcode for device testing

2. **Setup**:
   ```bash
   # Clone repository
   git clone <repository-url>
   cd route_guard
   
   # Get Flutter dependencies
   flutter pub get
   
   # Configure Supabase
   # 1. Update lib/supabase_options.dart with your project URL and anon key
   # 2. Apply supabase/schema.sql to your Supabase project
   # 3. Create storage bucket 'hazard-photos' (public)
   # 4. Deploy edge functions: supabase functions deploy
   # 5. Configure edge function environment variables
   
   # Run the app
   flutter run  # For device/emulator
   flutter run -d chrome  # For web testing
   ```

3. **Testing**:
   ```bash
   # Run widget tests
   flutter test
   ```

## Design Patterns Used
1. **Service Locator**: Centralized dependency injection
2. **Repository Pattern**: Abstracted data access through services
3. **Observer Pattern**: Real-time streams and state change listeners
4. **Singleton**: PerformanceMonitoringService, Supabase client
5. **Factory**: Model creation from JSON (`fromJson` constructors)
6. **Strategy**: Different notification implementations (Firebase vs local)
7. **Template Method**: Common service structure with performance monitoring
8. **MVC/MVVM**: Separation of UI, business logic, and data layers

## Security Considerations
1. **Row Level Security**: Enforced at database level
2. **Input Validation**: All Supabase operations use parameterized queries
3. **Secure Storage**: Hazard photos stored in Supabase Storage with public URLs
4. **API Keys**: Anon key exposed in client (standard Supabase practice), service key only in edge functions
5. **Data Minimization**: Only necessary data stored and transmitted
6. **Permission Scoping**: Location and notification permissions requested at runtime
7. **Error Handling**: Graceful degradation when services unavailable

## Future Enhancements
1. **Reputation-weighted voting**: Use actual reputation scores in weighted confirms/denies
2. **Geographic clustering**: Detect and merge nearby hazard reports
3. **Advanced routing**: Incorporate traffic data and user preferences
4. **Online/Offline symbology**: Visual indicators for data freshness
5. **Advanced filtering**: Hazard type, time range, severity filters on map
6. **Multilingual support**: Internationalization for global deployment
7. **Accessibility improvements**: Screen reader support, higher contrast modes
8. **Analytics**: Anonymous usage tracking for improvement insights

---
*This document provides a comprehensive overview of the RouteGuard project architecture, components, and functionality. For specific implementation details, refer to the source code files and inline comments.*