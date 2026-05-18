# Codex Implementation Brief — iPhone + Apple Watch Gym Training App

## 0. Goal

Build a native Apple ecosystem gym app composed of:

1. An **iPhone app** used to manage the exercise library, create workout plans, organize plans into training days, review history, and view dashboards.
2. An **Apple Watch companion app** used during training to select a plan/day, execute exercises set by set, input completed reps/time and load, automatically manage rest timers, and sync the completed workout back to the iPhone.

The app should be useful offline at the gym. The Apple Watch must be able to run a workout even if the iPhone is not immediately reachable, then sync later.

Use English in code comments, UI strings can be English for now.

---

## 1. Recommended Technical Stack

### Platforms

- iOS app: SwiftUI
- watchOS app: SwiftUI
- Shared code: a shared Swift module/package used by both targets
- Minimum suggested deployment:
  - iOS 17+
  - watchOS 10+
- Persistence:
  - Prefer **SwiftData** for local storage on iPhone.
  - On Watch, keep a lightweight local cache using SwiftData if available for the deployment target, or a JSON file cache if implementation becomes simpler.
- iPhone ↔ Watch communication:
  - Use **WatchConnectivity**.
  - iPhone is the source of truth for exercise library, plans, and long-term history.
  - Watch keeps a cached snapshot of active plans and pending workout logs.
- Optional but recommended:
  - **HealthKit** on Apple Watch to start a strength-training workout session, collect duration/heart-rate/calories when permission is granted, and keep the app active during the workout.
  - The core app must still work without HealthKit permission.

### Important Watch UX note

The user asked to enter reps/load “by drawing on the watch face.” In watchOS, do not rely on private APIs for handwriting recognition. Implement numeric input using one or more public approaches:

1. Primary: large numeric picker controlled by the **Digital Crown**.
2. Secondary: simple custom numeric keypad optimized for watch.
3. Optional: a SwiftUI `TextField` that allows the system-provided watch text input when available.

Use the Digital Crown picker as the first implementation because it is faster during workouts.

---

## 2. Product Requirements

### 2.1 iPhone App

The iPhone app must support these main sections:

1. **Exercise Library**
   - Create, edit, archive, and delete exercises.
   - Fields:
     - Name
     - Primary muscle group
     - Secondary muscle groups
     - Category: strength, cardio, mobility, warmup, other
     - Equipment: barbell, dumbbell, machine, cable, bodyweight, kettlebell, cardio machine, other
     - Description/instructions
     - Form cues
     - Common mistakes
     - Optional video URL
     - Optional notes
     - Default measurement type: reps-based or time-based
     - Default rest time
     - Default load unit: kg/lb/bodyweight
     - Whether unilateral/single-side
     - Whether warm-up exercise
     - Archived flag

2. **Workout Plans / Schede**
   - Create, edit, duplicate, archive, and delete workout plans.
   - A plan is divided into days.
   - Example plan:
     - “Upper/Lower 4 Days”
       - Day 1: Upper A
       - Day 2: Lower A
       - Day 3: Upper B
       - Day 4: Lower B
   - A day contains ordered workout exercise entries.
   - For each workout exercise entry, define:
     - Exercise reference
     - Order
     - Number of working sets
     - Optional warm-up sets
     - Target type:
       - fixed reps
       - rep range
       - fixed time
       - time range
       - AMRAP
     - Target reps/time per set
     - Starting load
     - Load increment suggestion
     - Rest time
     - RPE/RIR target, optional
     - Tempo, optional, e.g. `3-1-1`
     - Notes specific to this plan/day
     - Superset/group ID, optional
     - Whether to auto-progress
   - The user can reorder exercises and reorder days.

3. **Workout History**
   - List previous completed workouts.
   - Open workout details.
   - Show each exercise, set, reps/time, load, rest overrun, notes.
   - Allow editing past workout logs from iPhone.

4. **Dashboards**
   - Overview dashboard:
     - Weekly workouts completed
     - Total sets
     - Total volume
     - Total workout time
     - Most trained muscle groups
   - Exercise detail dashboard:
     - Estimated 1RM trend for reps-based strength exercises
     - Volume trend
     - Best set / personal record
     - Last performed sets
     - Suggested next load/reps based on progression rule
   - Plan adherence:
     - Planned vs completed sessions
     - Missed days
     - Average workout duration
   - Rest analysis:
     - Average rest time by exercise
     - Rest overrun frequency

5. **Settings**
   - Units: kg/lb
   - Default rest time
   - Haptics enabled/disabled for Watch
   - HealthKit integration enabled/disabled
   - Backup/export JSON
   - Import JSON
   - Reset demo data
   - Theme preference, optional

---

### 2.2 Apple Watch App

The Watch app must be optimized for the gym. It should minimize taps.

Main flow:

1. **Select Workout Plan**
   - Show synced active plans.
   - The user selects a plan.

2. **Select Training Day**
   - Show days for that plan.
   - Each day shows:
     - Name
     - Number of exercises
     - Estimated duration
     - Last completed date, if available

3. **Start Workout**
   - Show short preview:
     - Exercise count
     - Estimated duration
     - First exercise
   - Button: Start

4. **Active Workout Screen**
   - Display:
     - Current exercise name
     - Current set number / total sets
     - Target reps/time
     - Target load
     - Previous performance for the same exercise and comparable set:
       - last reps or last time
       - last load
       - date of previous workout
     - Current input controls
   - For reps-based exercises:
     - Input completed reps
     - Input load
   - For time-based exercises:
     - Start/stop timer or input completed seconds
     - Input load if applicable
   - Quick actions:
     - Complete Set
     - Skip Set
     - Previous/Next Exercise
     - Add Extra Set
     - Add Note
     - Pause Workout
     - Finish Workout

5. **After Completing a Set**
   - Save the completed set locally on Watch immediately.
   - Start rest timer automatically.
   - Rest screen:
     - Countdown from configured rest time.
     - Show next set/exercise preview.
     - When countdown reaches zero:
       - Trigger haptic feedback.
       - Do not stop the timer.
       - Continue counting upward as “over-rest”.
       - Change UI state to red/warning.
     - Buttons:
       - Start Next Set
       - Add +30s
       - Skip Rest

6. **Finish Workout**
   - Show summary:
     - Duration
     - Exercises completed
     - Total sets
     - Volume
     - PRs, if any
   - Save final workout session.
   - Sync to iPhone via WatchConnectivity.
   - If iPhone is unavailable, keep a pending upload queue.

---

## 3. Architecture

Use a clean modular structure.

```text
GymApp/
  GymApp.xcodeproj or GymApp.xcworkspace

  Shared/
    Models/
      Exercise.swift
      WorkoutPlan.swift
      WorkoutDay.swift
      WorkoutExercise.swift
      WorkoutSession.swift
      WorkoutSetLog.swift
      ProgressionRule.swift
      Units.swift
    DTO/
      SyncSnapshot.swift
      SyncWorkoutPayload.swift
      ExerciseDTO.swift
      WorkoutPlanDTO.swift
    Services/
      ProgressionEngine.swift
      PreviousPerformanceResolver.swift
      VolumeCalculator.swift
      DateUtils.swift
      UnitConversion.swift
    Sync/
      SyncMessage.swift
      SyncMessageType.swift

  iOSApp/
    App/
      GymTrainingApp.swift
    Persistence/
      ModelContainerProvider.swift
      SeedData.swift
      Repository.swift
    Features/
      ExerciseLibrary/
      PlanBuilder/
      WorkoutHistory/
      Dashboards/
      Settings/
    Sync/
      PhoneWatchSyncManager.swift

  WatchApp/
    App/
      GymTrainingWatchApp.swift
    Persistence/
      WatchCacheStore.swift
    Features/
      PlanSelection/
      ActiveWorkout/
      RestTimer/
      WorkoutSummary/
    Sync/
      WatchPhoneSyncManager.swift
    Health/
      WatchWorkoutSessionManager.swift
```

Implementation style:

- Prefer SwiftUI + MVVM or SwiftUI + Observable view models.
- Keep domain logic in Shared services, not inside views.
- Use DTOs for sync. Do not send SwiftData model objects directly through WatchConnectivity.
- Use UUIDs for stable identifiers.
- Use `createdAt`, `updatedAt`, and optional `deletedAt`/`archivedAt` for sync and soft deletion.
- iPhone remains the canonical store.
- Watch stores:
  - latest exercise/plan snapshot
  - active workout draft
  - completed workout payloads waiting to sync

---

## 4. Data Model

### 4.1 Enums

Create these enums as `String, Codable, CaseIterable, Identifiable` where appropriate.

```swift
enum MeasurementType: String, Codable {
    case repetitions
    case duration
}

enum ExerciseCategory: String, Codable {
    case strength
    case cardio
    case mobility
    case warmup
    case other
}

enum EquipmentType: String, Codable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case kettlebell
    case cardioMachine
    case other
}

enum LoadUnit: String, Codable {
    case kg
    case lb
    case bodyweight
}

enum SetTargetType: String, Codable {
    case fixedReps
    case repRange
    case fixedDuration
    case durationRange
    case amrap
}
```

---

### 4.2 Exercise

```swift
struct ExerciseDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var primaryMuscleGroup: String
    var secondaryMuscleGroups: [String]
    var category: ExerciseCategory
    var equipment: EquipmentType
    var description: String
    var formCues: [String]
    var commonMistakes: [String]
    var videoURL: URL?
    var notes: String
    var defaultMeasurementType: MeasurementType
    var defaultRestSeconds: Int
    var defaultLoadUnit: LoadUnit
    var isUnilateral: Bool
    var isWarmup: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}
```

For SwiftData, implement `@Model final class Exercise` with equivalent properties. If SwiftData has trouble with arrays, encode arrays as transformable data or use child models.

---

### 4.3 WorkoutPlan

```swift
struct WorkoutPlanDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var description: String
    var goal: String
    var days: [WorkoutDayDTO]
    var isActive: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}
```

---

### 4.4 WorkoutDay

```swift
struct WorkoutDayDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var planId: UUID
    var name: String
    var orderIndex: Int
    var notes: String
    var exercises: [WorkoutExerciseDTO]
}
```

---

### 4.5 WorkoutExercise

```swift
struct WorkoutExerciseDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var workoutDayId: UUID
    var exerciseId: UUID
    var orderIndex: Int

    var numberOfSets: Int
    var warmupSets: Int

    var targetType: SetTargetType
    var targetReps: Int?
    var targetRepsMin: Int?
    var targetRepsMax: Int?
    var targetDurationSeconds: Int?
    var targetDurationMinSeconds: Int?
    var targetDurationMaxSeconds: Int?

    var startingLoad: Double?
    var loadUnit: LoadUnit
    var suggestedIncrement: Double?
    var restSeconds: Int

    var rpeTarget: Double?
    var rirTarget: Int?
    var tempo: String?
    var notes: String

    var supersetGroupId: UUID?
    var autoProgressionEnabled: Bool
}
```

---

### 4.6 WorkoutSession

A session is a completed or in-progress workout.

```swift
struct WorkoutSessionDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var planId: UUID?
    var dayId: UUID?
    var planNameSnapshot: String
    var dayNameSnapshot: String

    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int

    var source: WorkoutSource
    var status: WorkoutStatus

    var setLogs: [WorkoutSetLogDTO]
    var notes: String
    var createdAt: Date
    var updatedAt: Date
}

enum WorkoutSource: String, Codable {
    case iphone
    case watch
}

enum WorkoutStatus: String, Codable {
    case inProgress
    case completed
    case cancelled
}
```

---

### 4.7 WorkoutSetLog

```swift
struct WorkoutSetLogDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var sessionId: UUID
    var exerciseId: UUID
    var workoutExerciseId: UUID?

    var exerciseNameSnapshot: String
    var setIndex: Int
    var isWarmup: Bool

    var targetReps: Int?
    var targetDurationSeconds: Int?
    var targetLoad: Double?
    var targetLoadUnit: LoadUnit

    var completedReps: Int?
    var completedDurationSeconds: Int?
    var completedLoad: Double?
    var completedLoadUnit: LoadUnit

    var restPlannedSeconds: Int
    var restActualSeconds: Int?

    var rpe: Double?
    var rir: Int?
    var notes: String

    var completedAt: Date
}
```

---

## 5. Previous Performance Logic

The Watch must show the user what they did last time.

Implement `PreviousPerformanceResolver` in Shared.

Input:

- exerciseId
- workoutExerciseId, optional
- setIndex
- previous completed sessions

Output:

```swift
struct PreviousSetPerformance: Codable, Hashable {
    var sessionDate: Date
    var completedReps: Int?
    var completedDurationSeconds: Int?
    var completedLoad: Double?
    var loadUnit: LoadUnit
    var rpe: Double?
    var notes: String?
}
```

Resolution rules:

1. Prefer previous sessions from the same workout plan and same day.
2. Match same `workoutExerciseId` if possible.
3. Otherwise match by `exerciseId`.
4. Prefer the same `setIndex`.
5. If that exact set is not available, show the closest previous set from that exercise.
6. Ignore warmup sets unless the current set is a warmup set.
7. If no data exists, show “No previous data”.

---

## 6. Progression Engine

Implement a basic progression suggestion system.

For reps-based exercises:

- If the user completed all sets at or above the top of the target range, suggest increasing load next time by `suggestedIncrement`.
- If the user missed the minimum target reps, suggest keeping or decreasing load.
- Otherwise keep load.

Example:

```swift
struct ProgressionSuggestion: Codable, Hashable {
    var suggestedLoad: Double?
    var message: String
    var reason: String
}
```

Example messages:

- “Increase to 62.5 kg next time.”
- “Keep 60 kg until you reach 10 reps on all sets.”
- “Consider reducing load if form degraded.”

Do not overcomplicate this in v1.

---

## 7. Sync Design

### 7.1 Source of Truth

- iPhone is source of truth for:
  - exercise library
  - workout plans
  - dashboards
  - long-term history
- Watch is source of truth only for:
  - the currently running workout
  - unsynced completed workout payloads

### 7.2 Sync Objects

Create a full snapshot sent from iPhone to Watch:

```swift
struct SyncSnapshot: Codable {
    var schemaVersion: Int
    var generatedAt: Date
    var exercises: [ExerciseDTO]
    var activePlans: [WorkoutPlanDTO]
    var recentSessions: [WorkoutSessionDTO]
}
```

Limit `recentSessions` sent to Watch:

- last 30–90 days
- enough to show previous performance
- do not send years of history to Watch

Create workout payload sent from Watch to iPhone:

```swift
struct SyncWorkoutPayload: Codable {
    var schemaVersion: Int
    var sentAt: Date
    var session: WorkoutSessionDTO
}
```

Create message wrapper:

```swift
enum SyncMessageType: String, Codable {
    case snapshotRequest
    case snapshotResponse
    case workoutCompleted
    case workoutAck
}

struct SyncMessage: Codable {
    var id: UUID
    var type: SyncMessageType
    var createdAt: Date
    var payload: Data?
}
```

### 7.3 WatchConnectivity Behavior

Implement:

- On iPhone app launch:
  - activate WatchConnectivity session
  - send latest snapshot if Watch is reachable
- On plan/exercise update:
  - regenerate snapshot
  - transfer via `updateApplicationContext` for latest state
  - optionally use `transferUserInfo` for queued delivery
- On Watch launch:
  - request latest snapshot
  - load cached snapshot immediately
  - update UI when new snapshot arrives
- On completed workout:
  - save payload locally on Watch pending queue
  - try immediate message if reachable
  - also queue transfer if not reachable
  - remove from pending queue only after iPhone sends ack

### 7.4 Conflict Handling

For v1:

- If a completed Watch workout has a UUID that already exists on iPhone, ignore duplicate.
- If an exercise or plan was archived on iPhone but still exists in a Watch active workout, allow the workout to finish using snapshot names.
- Workout logs use snapshot names to preserve history even if the exercise is renamed later.

---

## 8. iPhone UI Details

### 8.1 App Navigation

Use a tab-based layout:

1. Exercises
2. Plans
3. History
4. Dashboard
5. Settings

---

### 8.2 Exercise Library Screens

#### ExerciseListView

- Search bar
- Filter by muscle group/category/equipment
- List active exercises
- Toggle to show archived exercises
- Add button

#### ExerciseEditorView

Fields:

- Name
- Primary muscle group
- Secondary muscle groups
- Category
- Equipment
- Description
- Form cues
- Common mistakes
- Video URL
- Notes
- Default measurement type
- Default rest
- Default load unit
- Unilateral toggle
- Warmup toggle

Validation:

- Name is required.
- Default rest must be >= 0.
- Video URL must be valid if present.

---

### 8.3 Plan Builder Screens

#### PlanListView

- Active plans first
- Duplicate plan action
- Archive plan action
- Activate/deactivate plan action

#### PlanEditorView

- Plan name
- Description
- Goal
- Days list
- Add day
- Reorder days

#### WorkoutDayEditorView

- Day name
- Notes
- Ordered exercise list
- Add exercise from library
- Reorder exercises
- Edit exercise prescription

#### WorkoutExerciseEditorView

Fields:

- Exercise selector
- Number of sets
- Warmup sets
- Target type
- Reps or time configuration
- Starting load
- Load unit
- Suggested increment
- Rest time
- RPE/RIR target
- Tempo
- Notes
- Superset group, optional
- Auto-progression toggle

Validation:

- Exercise is required.
- Number of sets must be > 0.
- Rest seconds must be >= 0.
- Reps/time targets must match target type.
- Load cannot be negative.

---

### 8.4 History Screens

#### WorkoutHistoryListView

- Group by month/week
- Show:
  - date
  - plan/day
  - duration
  - total sets
  - total volume

#### WorkoutSessionDetailView

- Summary metrics
- Exercise sections
- Set table:
  - set number
  - reps/time
  - load
  - rest
  - RPE/RIR
- Edit mode
- Delete session action with confirmation

---

### 8.5 Dashboard Screens

Use Swift Charts if available.

Create these charts:

1. Weekly workout count
2. Weekly total volume
3. Exercise volume trend
4. Estimated 1RM trend
5. Muscle group distribution
6. Rest time average by exercise

Estimated 1RM formula for v1:

```text
Epley: estimated1RM = weight * (1 + reps / 30)
```

Only compute when:

- exercise is reps-based
- load > 0
- reps > 0

---

## 9. Apple Watch UI Details

### 9.1 Watch Navigation

Use simple screens:

1. `WatchPlanListView`
2. `WatchDayListView`
3. `WatchWorkoutPreviewView`
4. `ActiveExerciseView`
5. `SetInputView`
6. `RestTimerView`
7. `WorkoutSummaryView`

Keep text large. Minimize scrolling.

---

### 9.2 ActiveExerciseView

Display:

- Exercise name
- Set `2 / 4`
- Target: `8–10 reps`
- Suggested load: `60 kg`
- Previous: `Last: 9 reps × 57.5 kg`
- Buttons:
  - Log Set
  - Skip
  - More

For time-based exercise:

- Show target time.
- Provide Start/Stop time button.
- Allow manual adjustment.

---

### 9.3 Numeric Input

Create a reusable `WatchNumberInputView`.

Requirements:

- Works for reps and load.
- Supports Digital Crown adjustment.
- Has plus/minus buttons.
- Has quick chips:
  - reps: `+1`, `-1`
  - load: `+2.5`, `-2.5`, or based on unit/increment
- Has confirm button.
- Starts with suggested value:
  - previous set value if available
  - otherwise target value
  - otherwise 0

Example flow after tapping “Log Set”:

1. Reps input screen.
2. Load input screen.
3. Confirm set summary.
4. Start rest automatically.

To reduce friction later, allow a compact single-screen version with both reps and load.

---

### 9.4 Rest Timer

Create `RestTimerView`.

State:

```swift
enum RestTimerState {
    case countingDown
    case overRest
    case skipped
    case completed
}
```

Behavior:

- Starts at planned rest seconds.
- Counts down every second.
- At zero:
  - trigger haptic
  - switch to `overRest`
  - UI becomes warning/red
  - timer continues counting upward
- Store actual rest time when user taps “Start Next Set”.
- Support:
  - `+30s`
  - `Skip Rest`
  - `Start Next Set`

Do not block the user from starting the next set early.

---

### 9.5 Active Workout Persistence

The Watch app must persist the in-progress workout after every set.

If the Watch app is killed or the screen turns off:

- Restore active session from local cache.
- Show “Resume workout?”
- Continue from latest completed set.

Data to persist:

```swift
struct ActiveWorkoutDraft: Codable {
    var session: WorkoutSessionDTO
    var currentExerciseIndex: Int
    var currentSetIndex: Int
    var restTimerStartedAt: Date?
    var plannedRestSeconds: Int?
}
```

---

## 10. HealthKit Optional Integration

Implement this after the core workout flow works.

If user grants HealthKit permission:

- Start a strength training workout session on Watch when workout starts.
- End the HealthKit workout when app workout finishes.
- Save:
  - workout duration
  - heart-rate samples if available
  - active calories if available
- Show HealthKit metrics in iPhone workout detail if synced.

If permission is denied:

- Continue normal app workout tracking.

Do not make HealthKit mandatory.

---

## 11. Notifications, Haptics, and Visual States

### Watch haptics

Use haptics for:

- Rest completed
- Set saved
- Workout completed

Respect Settings toggle.

### Visual states

Rest timer:

- Normal countdown: neutral
- Last 5 seconds: emphasized
- Over-rest: red/warning

Workout state:

- Paused: yellow/warning
- Finished: success

---

## 12. Dashboard Metrics

Implement calculators in Shared.

### Total Volume

For each set:

```text
volume = completedLoad * completedReps
```

Only count reps-based sets with load.

For bodyweight exercises, v1 can either:

- skip volume, or
- use bodyweight if the user stores bodyweight in Settings later.

### Total Sets

Count completed non-skipped sets.

### Estimated 1RM

Use Epley:

```text
estimated1RM = weight * (1 + reps / 30)
```

### Personal Records

Track:

- Max load for exercise
- Max reps at load
- Best estimated 1RM
- Best volume in a session for exercise

### Adherence

For v1:

- planned sessions per week can be manually configured on plan.
- completed sessions per week = sessions completed.
- adherence = completed / planned.

---

## 13. Seed Data

Create demo data so the app is immediately testable.

Exercises:

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

Plans:

1. Full Body 3 Days
   - Day A
   - Day B
   - Day C

2. Upper Lower 4 Days
   - Upper A
   - Lower A
   - Upper B
   - Lower B

Include realistic prescriptions.

---

## 14. Implementation Milestones

### Milestone 1 — Project skeleton

- Create iOS app target.
- Create watchOS companion target.
- Create shared module.
- Add basic SwiftUI navigation.
- Add seed data.

Acceptance criteria:

- iPhone app launches.
- Watch app launches.
- Shared DTOs compile in both targets.

---

### Milestone 2 — Core data model and iPhone CRUD

- Implement SwiftData models.
- Implement repositories.
- Exercise CRUD.
- Plan/day/exercise prescription CRUD.
- Reordering.

Acceptance criteria:

- User can create exercises.
- User can create a plan with multiple days.
- User can add exercises to days and configure sets/reps/load/rest.

---

### Milestone 3 — Watch snapshot sync

- Implement PhoneWatchSyncManager.
- Implement WatchPhoneSyncManager.
- Send snapshot from iPhone to Watch.
- Watch caches snapshot.
- Watch lists plans and days.

Acceptance criteria:

- Create/edit a plan on iPhone.
- Open Watch app.
- Plan appears on Watch.

---

### Milestone 4 — Watch workout execution

- Implement active workout flow.
- Show previous performance.
- Implement reps/load input.
- Implement time-based exercise input.
- Implement automatic rest timer.
- Implement haptic and over-rest state.
- Persist active workout draft.

Acceptance criteria:

- User can complete a full workout on Watch.
- Each set records reps/time, load, and actual rest.
- If app is closed, the workout can resume.

---

### Milestone 5 — Sync completed workouts back to iPhone

- Watch queues completed workout payload.
- iPhone receives and stores session.
- iPhone sends ack.
- Watch clears pending queue only after ack.
- Prevent duplicate imports.

Acceptance criteria:

- Complete workout on Watch.
- Workout appears in iPhone history.
- Duplicate sync does not create duplicate workouts.

---

### Milestone 6 — Dashboards

- Implement history list/detail.
- Implement volume charts.
- Implement exercise detail trend.
- Implement PR detection.
- Implement rest analysis.

Acceptance criteria:

- iPhone dashboard updates after Watch workout sync.
- Exercise detail shows last sessions and trend.

---

### Milestone 7 — HealthKit and polish

- Add optional HealthKit permission flow.
- Start/end workout session on Watch.
- Add settings.
- Add export/import.
- Improve empty states.
- Add error handling.
- Add unit tests.

Acceptance criteria:

- App works with and without HealthKit.
- User can export data.
- Common failures show friendly messages.

---

## 15. Testing Plan

### Unit tests

Test:

- PreviousPerformanceResolver
- ProgressionEngine
- VolumeCalculator
- UnitConversion
- Sync duplicate detection
- Rest timer state transition

### UI tests

Test iPhone:

- Create exercise
- Create plan
- Add day
- Add exercise to day
- Save plan

Test Watch manually or with previews where possible:

- Select plan/day
- Complete reps-based set
- Complete time-based set
- Rest timer over-rest behavior
- Finish workout

### Sync tests

Test:

- Watch reachable immediate sync
- Watch offline queue
- Duplicate workout payload
- Snapshot update after editing plan

---

## 16. Error Handling

Handle these cases:

- No plans on Watch:
  - “Create a workout plan on iPhone first.”
- iPhone unreachable:
  - “Using cached plans. Workout will sync later.”
- No previous performance:
  - “No previous data.”
- Plan changed while workout is active:
  - Continue using local snapshot.
- Failed sync:
  - Keep pending queue and retry.
- Invalid exercise prescription:
  - Prevent saving on iPhone.

---

## 17. Security and Privacy

- Do not require a backend for v1.
- All data remains local to the user’s devices.
- If HealthKit is enabled, request only necessary permissions.
- Make export/import explicit.
- Do not collect analytics in v1 unless explicitly added later.

---

## 18. Future Features

Do not implement these in v1 unless the core app is complete:

- iCloud sync across multiple iPhones/iPads
- Social sharing
- AI-generated plans
- Plate calculator
- Superset-specific watch UI
- Live Activity on iPhone
- Watch complications/widgets
- Exercise media upload
- Automatic progressive overload plans
- Deload detection
- Body measurements and bodyweight tracking

---

## 19. Codex Development Instructions

When implementing this project:

1. Build the smallest working vertical slice first:
   - seed exercises on iPhone
   - seed one plan
   - sync to Watch
   - complete one workout on Watch
   - sync result back to iPhone history
2. Keep views simple and functional before polishing UI.
3. Use clear filenames and keep each file focused.
4. Do not put business logic inside SwiftUI views.
5. Prefer explicit DTO mapping between persistence models and sync models.
6. Add comments only where they clarify non-obvious decisions.
7. Avoid introducing a backend.
8. Avoid external dependencies unless strongly justified.
9. Keep the app usable offline.
10. Make sure every model has stable UUIDs and timestamps.
11. Implement safe defaults and demo data.
12. Every milestone must compile before moving to the next.

---

## 20. Definition of Done for v1

The v1 is complete when:

- The user can create exercises on iPhone.
- The user can create a workout plan divided into days.
- Each day can contain configured exercises with sets, reps/time, load, rest, and notes.
- The Apple Watch can select a plan and day.
- The Watch guides the user through exercises and sets.
- The Watch shows previous performance for each set when available.
- The user can enter reps/time and load from the Watch.
- Rest starts automatically after each set.
- The Watch vibrates when rest ends.
- Rest timer continues after zero and changes to warning/red state.
- Finished workouts sync back to iPhone.
- iPhone history shows completed workouts.
- iPhone dashboards show basic progress metrics.
- The app works without internet.
- The app handles temporary Watch/iPhone disconnection.
