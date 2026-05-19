import Foundation
import SpotterShared
import SwiftData

enum SpotterRepository {
    static func insertExercise(named name: String, in context: ModelContext) -> ExerciseModel {
        let exercise = ExerciseModel(name: name)
        context.insert(exercise)
        return exercise
    }

    static func insertPlan(named name: String, in context: ModelContext) -> WorkoutPlanModel {
        let plan = WorkoutPlanModel(name: name)
        context.insert(plan)
        return plan
    }

    static func insertDay(named name: String, into plan: WorkoutPlanModel) -> WorkoutDayModel {
        let day = WorkoutDayModel(
            planId: plan.id,
            name: name,
            orderIndex: plan.days.count
        )
        plan.days.append(day)
        plan.updatedAt = Date()
        return day
    }

    static func insertPrescription(
        exerciseId: UUID,
        into day: WorkoutDayModel
    ) -> WorkoutExerciseModel {
        let prescription = WorkoutExerciseModel(
            workoutDayId: day.id,
            exerciseId: exerciseId,
            orderIndex: day.exercises.count
        )
        day.exercises.append(prescription)
        return prescription
    }

    static func delete<T: PersistentModel>(_ model: T, from context: ModelContext) {
        context.delete(model)
    }

    @discardableResult
    static func importCompletedWorkout(
        _ session: WorkoutSessionDTO,
        in context: ModelContext
    ) throws -> WorkoutSessionModel {
        let sessionId = session.id
        let descriptor = FetchDescriptor<WorkoutSessionModel>(
            predicate: #Predicate { $0.id == sessionId }
        )

        if let existingSession = try context.fetch(descriptor).first {
            if existingSession.status != .completed {
                existingSession.update(from: session)
                try context.save()
            }
            return existingSession
        }

        let newSession = WorkoutSessionModel(dto: session)
        context.insert(newSession)
        try context.save()
        return newSession
    }
}
