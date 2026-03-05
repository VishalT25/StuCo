import Foundation
import Supabase
import OSLog

// MARK: - Base Repository Protocol
protocol Repository {
  associatedtype DBRow: DatabaseModel
  associatedtype LocalModel = DBRow.LocalModel

  var tableName: String { get }

  func create(_ item: LocalModel, userId: String) async throws -> LocalModel
  func read(id: String) async throws -> LocalModel?
  func readAll(userId: String) async throws -> [LocalModel]
  func update(_ item: LocalModel, userId: String) async throws -> LocalModel
  func delete(id: String) async throws
  func deleteAll(userId: String) async throws
}

// MARK: - Base Repository Implementation
class BaseRepository<DBRow: DatabaseModel, LocalModel>: Repository where DBRow.LocalModel == LocalModel {
  let supabaseService: SupabaseService
  let tableName: String

  init(supabaseService: SupabaseService = .shared, tableName: String) {
    self.supabaseService = supabaseService
    self.tableName = tableName
  }

  var client: SupabaseClient { supabaseService.database }

  private func logPayload(_ action: String, payload: any Encodable) {
    #if DEBUG
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    if let data = try? encoder.encode(AnyEncodable(payload)),
       let json = String(data: data, encoding: .utf8) {
      print("🗄️ DB \(action.uppercased()) \(tableName) payload: \(json)")
    } else {
      print("🗄️ DB \(action.uppercased()) \(tableName) payload: <encoding failed>")
    }
    #endif
  }

  private func logResult(_ action: String, resultData: Data?) {
    #if DEBUG
    if let data = resultData,
       let json = String(data: data, encoding: .utf8) {
      print("🗄️ DB \(action.uppercased()) \(tableName) result: \(json)")
    } else {
      print("🗄️ DB \(action.uppercased()) \(tableName) result: <no data>")
    }
    #endif
  }

  func create(_ item: LocalModel, userId: String) async throws -> LocalModel {
    await supabaseService.ensureValidToken()
    let dbModel = DBRow(from: item, userId: userId)
    logPayload("insert", payload: dbModel)

    do {
      let response = try await client
        .from(tableName)
        .insert(dbModel)
        .select()
        .single()
        .execute()

      logResult("insert", resultData: response.data)
      let returned = try JSONDecoder().decode(DBRow.self, from: response.data)
      return returned.toLocal()
    } catch {
      print("🛑 DB INSERT \(tableName) failed: \(error)")
      throw error
    }
  }

  func update(_ item: LocalModel, userId: String) async throws -> LocalModel {
    await supabaseService.ensureValidToken()
    let dbModel = DBRow(from: item, userId: userId)
    logPayload("update", payload: dbModel)

    do {
      let response = try await client
        .from(tableName)
        .update(dbModel)
        .eq("id", value: dbModel.id)
        .select()
        .single()
        .execute()

      logResult("update", resultData: response.data)
      let returned = try JSONDecoder().decode(DBRow.self, from: response.data)
      return returned.toLocal()
    } catch {
      print("🛑 DB UPDATE \(tableName) failed: \(error)")
      throw error
    }
  }

  // Upsert: Insert if not exists, update if exists
  func upsert(_ item: LocalModel, userId: String) async throws -> LocalModel {
    await supabaseService.ensureValidToken()
    let dbModel = DBRow(from: item, userId: userId)
    logPayload("upsert", payload: dbModel)

    do {
      let response = try await client
        .from(tableName)
        .upsert(dbModel)
        .select()
        .single()
        .execute()

      logResult("upsert", resultData: response.data)
      let returned = try JSONDecoder().decode(DBRow.self, from: response.data)
      return returned.toLocal()
    } catch {
      print("🛑 DB UPSERT \(tableName) failed: \(error)")
      throw error
    }
  }

  func read(id: String) async throws -> LocalModel? {
    await supabaseService.ensureValidToken()
    do {
      let response = try await client
        .from(tableName)
        .select()
        .eq("id", value: id)
        .single()
        .execute()
      logResult("read", resultData: response.data)
      let dbModel = try JSONDecoder().decode(DBRow.self, from: response.data)
      return dbModel.toLocal()
    } catch let pgErr as PostgrestError {
      if pgErr.code == "PGRST116" {
        return nil
      }
      print("🛑 DB READ \(tableName) failed: \(pgErr)")
      throw pgErr
    } catch {
      if error.localizedDescription.contains("Cannot coerce the result to a single JSON object") {
        return nil
      }
      print("🛑 DB READ \(tableName) failed: \(error)")
      throw error
    }
  }

  func readAll(userId: String) async throws -> [LocalModel] {
    await supabaseService.ensureValidToken()
    do {
      let response = try await client
        .from(tableName)
        .select()
        .eq("user_id", value: userId)
        .execute()
      logResult("readAll", resultData: response.data)
      let dbModels = try JSONDecoder().decode([DBRow].self, from: response.data)
      return dbModels.map { $0.toLocal() }
    } catch {
      print("🛑 DB READ ALL \(tableName) failed: \(error)")
      throw error
    }
  }

  func delete(id: String) async throws {
    await supabaseService.ensureValidToken()
    #if DEBUG
    print("🗄️ DB DELETE \(tableName) id=\(id)")
    #endif
    do {
      _ = try await client
        .from(tableName)
        .delete()
        .eq("id", value: id)
        .execute()
    } catch {
      print("🛑 DB DELETE \(tableName) failed: \(error)")
      throw error
    }
  }

  func deleteAll(userId: String) async throws {
    await supabaseService.ensureValidToken()
    #if DEBUG
    print("🗄️ DB DELETE ALL \(tableName) user_id=\(userId)")
    #endif
    do {
      _ = try await client
        .from(tableName)
        .delete()
        .eq("user_id", value: userId)
        .execute()
    } catch {
      print("🛑 DB DELETE ALL \(tableName) failed: \(error)")
      throw error
    }
  }
}

// MARK: - Specific Repository Implementations

class AcademicCalendarRepository: BaseRepository<DatabaseAcademicCalendar, AcademicCalendar> {
  init(supabaseService: SupabaseService = .shared) {
    super.init(supabaseService: supabaseService, tableName: "academic_calendars")
  }

  func findByYear(_ year: String, userId: String) async throws -> [AcademicCalendar] {
    await supabaseService.ensureValidToken()

    let response = try await client
      .from(tableName)
      .select()
      .eq("user_id", value: userId)
      .eq("academic_year", value: year)
      .execute()

    let dbModels = try JSONDecoder().decode([DatabaseAcademicCalendar].self, from: response.data)
    return dbModels.map { $0.toLocal() }
  }
}

class AssignmentRepository: BaseRepository<DatabaseAssignment, Assignment> {
  init(supabaseService: SupabaseService = .shared) {
    super.init(supabaseService: supabaseService, tableName: "assignments")
  }

  func findByCourse(_ courseId: String) async throws -> [Assignment] {
    await supabaseService.ensureValidToken()

    let response = try await client
      .from(tableName)
      .select()
      .eq("course_id", value: courseId)
      .execute()

    let dbModels = try JSONDecoder().decode([DatabaseAssignment].self, from: response.data)
    return dbModels.map { $0.toLocal() }
  }
}

class CategoryRepository: BaseRepository<DatabaseCategory, Category> {
  init(supabaseService: SupabaseService = .shared) {
    super.init(supabaseService: supabaseService, tableName: "categories")
  }
}

class CourseRepository: BaseRepository<DatabaseCourse, Course> {
  init(supabaseService: SupabaseService = .shared) {
    super.init(supabaseService: supabaseService, tableName: "courses")
  }

  func findBySchedule(_ scheduleId: String, userId: String) async throws -> [Course] {
    await supabaseService.ensureValidToken()

    let response = try await client
      .from(tableName)
      .select()
      .eq("user_id", value: userId)
      .eq("schedule_id", value: scheduleId)
      .execute()

    let dbModels = try JSONDecoder().decode([DatabaseCourse].self, from: response.data)
    return dbModels.map { $0.toLocal() }
  }
}

class EventRepository: BaseRepository<DatabaseEvent, Event> {
  init(supabaseService: SupabaseService = .shared) {
    super.init(supabaseService: supabaseService, tableName: "events")
  }

  func findByDateRange(start: Date, end: Date, userId: String) async throws -> [Event] {
    await supabaseService.ensureValidToken()

    let startStr = start.toISOString()
    let endStr = end.toISOString()

    let response = try await client
      .from(tableName)
      .select()
      .eq("user_id", value: userId)
      .gte("event_date", value: startStr)
      .lte("event_date", value: endStr)
      .order("event_date")
      .execute()

    let dbModels = try JSONDecoder().decode([DatabaseEvent].self, from: response.data)
    return dbModels.map { $0.toLocal() }
  }

  func findByCourse(_ courseId: String, userId: String) async throws -> [Event] {
    await supabaseService.ensureValidToken()

    let response = try await client
      .from(tableName)
      .select()
      .eq("user_id", value: userId)
      .eq("course_id", value: courseId)
      .execute()

    let dbModels = try JSONDecoder().decode([DatabaseEvent].self, from: response.data)
    return dbModels.map { $0.toLocal() }
  }

  func findByCategory(_ categoryId: String, userId: String) async throws -> [Event] {
    await supabaseService.ensureValidToken()

    let response = try await client
      .from(tableName)
      .select()
      .eq("user_id", value: userId)
      .eq("category_id", value: categoryId)
      .execute()

    let dbModels = try JSONDecoder().decode([DatabaseEvent].self, from: response.data)
    return dbModels.map { $0.toLocal() }
  }

  func findIncomplete(userId: String) async throws -> [Event] {
    await supabaseService.ensureValidToken()

    let response = try await client
      .from(tableName)
      .select()
      .eq("user_id", value: userId)
      .eq("is_completed", value: false)
      .order("event_date")
      .execute()

    let dbModels = try JSONDecoder().decode([DatabaseEvent].self, from: response.data)
    return dbModels.map { $0.toLocal() }
  }
}

class ScheduleRepository: BaseRepository<DatabaseSchedule, ScheduleCollection> {
  init(supabaseService: SupabaseService = .shared) {
    super.init(supabaseService: supabaseService, tableName: "schedules")
  }

  func findActive(userId: String) async throws -> ScheduleCollection? {
    await supabaseService.ensureValidToken()

    let response = try await client
      .from(tableName)
      .select()
      .eq("user_id", value: userId)
      .eq("is_active", value: true)
      .eq("is_archived", value: false)
      .single()
      .execute()

    let dbModel = try JSONDecoder().decode(DatabaseSchedule.self, from: response.data)
    return dbModel.toLocal()
  }

  func findArchived(userId: String) async throws -> [ScheduleCollection] {
    await supabaseService.ensureValidToken()

    let response = try await client
      .from(tableName)
      .select()
      .eq("user_id", value: userId)
      .eq("is_archived", value: true)
      .execute()

    let dbModels = try JSONDecoder().decode([DatabaseSchedule].self, from: response.data)
    return dbModels.map { $0.toLocal() }
  }

  func setActive(scheduleId: String, userId: String) async throws {
    await supabaseService.ensureValidToken()

    _ = try await client
      .from(tableName)
      .update(["is_active": false])
      .eq("user_id", value: userId)
      .execute()

    _ = try await client
      .from(tableName)
      .update(["is_active": true])
      .eq("id", value: scheduleId)
      .eq("user_id", value: userId)
      .execute()
  }
}

class ScheduleItemRepository: BaseRepository<DatabaseScheduleItem, ScheduleItem> {
  init(supabaseService: SupabaseService = .shared) {
    super.init(supabaseService: supabaseService, tableName: "schedule_items")
  }

  func findBySchedule(_ scheduleId: String) async throws -> [ScheduleItem] {
    await supabaseService.ensureValidToken()

    let response = try await client
      .from(tableName)
      .select()
      .eq("schedule_id", value: scheduleId)
      .execute()

    let dbModels = try JSONDecoder().decode([DatabaseScheduleItem].self, from: response.data)
    return dbModels.map { $0.toLocal() }
  }

  func createWithSchedule(_ item: ScheduleItem, userId: String, scheduleId: String, courseId: String? = nil) async throws -> ScheduleItem {
    await supabaseService.ensureValidToken()

    let dbModel = DatabaseScheduleItem(from: item, userId: userId, scheduleId: scheduleId, courseId: courseId)

    let response = try await client
      .from(tableName)
      .insert(dbModel)
      .select()
      .single()
      .execute()

    let returnedModel = try JSONDecoder().decode(DatabaseScheduleItem.self, from: response.data)
    return returnedModel.toLocal()
  }

  func updateWithSchedule(_ item: ScheduleItem, userId: String, scheduleId: String, courseId: String? = nil) async throws -> ScheduleItem {
    await supabaseService.ensureValidToken()

    let dbModel = DatabaseScheduleItem(from: item, userId: userId, scheduleId: scheduleId, courseId: courseId)

    let response = try await client
      .from(tableName)
      .update(dbModel)
      .eq("id", value: dbModel.id)
      .select()
      .single()
      .execute()

    let returnedModel = try JSONDecoder().decode(DatabaseScheduleItem.self, from: response.data)
    return returnedModel.toLocal()
  }

  override func readAll(userId: String) async throws -> [ScheduleItem] {
    await supabaseService.ensureValidToken()
    do {
      let response = try await client
        .from("schedule_items")
        .select("""
          *,
          schedules!schedule_items_schedule_id_fkey!inner(user_id)
        """)
        .eq("schedules.user_id", value: userId)
        .execute()

      let dbModels = try JSONDecoder().decode([DatabaseScheduleItem].self, from: response.data)
      return dbModels.map { $0.toLocal() }
    } catch {
      let response = try await client
        .from("schedule_items")
        .select("""
          *,
          schedules!fk_schedule_items_schedule_id!inner(user_id)
        """)
        .eq("schedules.user_id", value: userId)
        .execute()

      let dbModels = try JSONDecoder().decode([DatabaseScheduleItem].self, from: response.data)
      return dbModels.map { $0.toLocal() }
    }
  }
}

class CourseMeetingRepository: BaseRepository<DatabaseCourseMeeting, CourseMeeting> {
  init(supabaseService: SupabaseService = .shared) {
    super.init(supabaseService: supabaseService, tableName: "course_meetings")
  }

  func findByCourse(_ courseId: String, userId: String) async throws -> [CourseMeeting] {
    await supabaseService.ensureValidToken()
    let response = try await client
      .from(tableName)
      .select()
      .eq("user_id", value: userId)
      .eq("course_id", value: courseId)
      .execute()
    let dbModels = try JSONDecoder().decode([DatabaseCourseMeeting].self, from: response.data)
    return dbModels.map { $0.toLocal() }
  }

  func findBySchedule(_ scheduleId: String, userId: String) async throws -> [CourseMeeting] {
    await supabaseService.ensureValidToken()
    let response = try await client
      .from(tableName)
      .select()
      .eq("user_id", value: userId)
      .eq("schedule_id", value: scheduleId)
      .execute()
    let dbModels = try JSONDecoder().decode([DatabaseCourseMeeting].self, from: response.data)
    return dbModels.map { $0.toLocal() }
  }
}

private struct AnyEncodable: Encodable {
  private let _encode: (Encoder) throws -> Void
  init<T: Encodable>(_ wrapped: T) {
    _encode = wrapped.encode
  }
  func encode(to encoder: Encoder) throws { try _encode(encoder) }
}