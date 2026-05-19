# Spotter

Spotter is a native Apple gym training app for iPhone and Apple Watch.

The product goal is an offline-first training companion: the iPhone manages exercises, workout plans, history, and dashboards, while the Apple Watch is optimized for selecting a plan and logging workouts at the gym.

## Current Status

Implemented so far:

- iPhone SwiftUI app target.
- watchOS SwiftUI companion app target.
- Shared Swift package, `SpotterShared`, for Codable DTOs, enums, and seed data.
- iPhone tab navigation for Exercises, Plans, History, Dashboard, and Settings.
- Watch navigation for plan and day selection.
- iPhone SwiftData models for exercises, workout plans, workout days, and exercise prescriptions.
- Minimal iPhone CRUD for exercises and plans.
- Demo seed exercises and plans.

Not implemented yet:

- WatchConnectivity sync.
- Watch workout execution.
- Completed workout import.
- Workout history persistence.
- Dashboards and charts.
- HealthKit integration.

## Platform

- iOS 26+
- watchOS 26+
- SwiftUI
- SwiftData on iPhone
- Local Swift package for shared models and DTOs

UI work should follow Apple's Liquid Glass direction where applicable, while staying native, minimal, and practical for the current milestone.

## Requirements

- Xcode with iOS 26 and watchOS 26 SDKs.
- An Apple developer team configured in Xcode for device builds.
- No backend or external runtime dependencies are required.

## Getting Started

Open the project:

```sh
open Spotter.xcodeproj
```

Select the `Spotter` scheme to run the iPhone app.

Select the `Spotter Watch App` scheme to run the watchOS app.

Build from the command line after Xcode is installed and selected:

```sh
xcodebuild -project Spotter.xcodeproj -scheme Spotter -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Validate the shared package:

```sh
cd Shared
swift build
```

If `xcodebuild` reports that Command Line Tools are selected instead of Xcode, select Xcode first:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Project Structure

```text
Spotter.xcodeproj
Shared/
  Package.swift
  Sources/SpotterShared/
    DTO/
    Models/
    SeedData/
iOSApp/
  App/
  Persistence/
    Models/
    Repositories/
    SeedData/
  Features/
    AppNavigation/
    ExerciseLibrary/
    PlanBuilder/
    WorkoutHistory/
    Dashboard/
    Settings/
WatchApp/
  App/
  Features/
    PlanSelection/
docs/
```

## Data Ownership

The iPhone is the source of truth for exercises, plans, and long-term history.

The Watch will later cache plan snapshots and queue completed workouts while offline. SwiftData models are not sent through WatchConnectivity; shared Codable DTOs are used at sync boundaries.

## Seed Data

The app seeds demo data on first launch if the local exercise store is empty.

Seed exercises include:

- Bench Press
- Squat
- Deadlift
- Overhead Press
- Lat Pulldown
- Barbell Row
- Dumbbell Curl
- Triceps Pushdown
- Plank
- Treadmill Run

Seed plans include:

- Full Body 3 Days
- Upper Lower 4 Days

## Development Notes

- Keep work scoped to the current milestone.
- Keep the app usable offline.
- Avoid introducing a backend.
- Avoid external dependencies unless they are explicitly justified.
- Keep business logic out of SwiftUI views when it grows beyond simple screen state.
- Use shared DTOs for iPhone and Watch communication boundaries.

## Roadmap

1. Project skeleton.
2. SwiftData models and iPhone CRUD.
3. Watch snapshot sync.
4. Watch workout execution.
5. Sync completed workouts back to iPhone.
6. Dashboards.
7. HealthKit and polish.
