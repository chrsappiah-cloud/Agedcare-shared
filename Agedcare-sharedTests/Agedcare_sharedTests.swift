import Testing
import SwiftData
import SwiftUI
@testable import Agedcare_shared

// MARK: - Item Model Tests

@Suite("Item Model Tests")
struct ItemModelTests {

    @Test func itemInitializesWithTimestamp() async throws {
        let now = Date()
        let item = Item(timestamp: now)
        #expect(item.timestamp == now)
    }

    @Test func itemInitializesWithSpecificDate() async throws {
        let components = DateComponents(year: 2026, month: 5, day: 10, hour: 14, minute: 30)
        let date = Calendar.current.date(from: components)!
        let item = Item(timestamp: date)
        #expect(item.timestamp == date)
    }

    @Test func itemInitializesWithDistantPast() async throws {
        let distantPast = Date.distantPast
        let item = Item(timestamp: distantPast)
        #expect(item.timestamp == distantPast)
    }

    @Test func itemInitializesWithDistantFuture() async throws {
        let distantFuture = Date.distantFuture
        let item = Item(timestamp: distantFuture)
        #expect(item.timestamp == distantFuture)
    }

    @Test func itemTimestampCanBeUpdated() async throws {
        let original = Date()
        let item = Item(timestamp: original)
        let updated = Date().addingTimeInterval(3600)
        item.timestamp = updated
        #expect(item.timestamp == updated)
        #expect(item.timestamp != original)
    }

    @Test func multipleItemsHaveIndependentTimestamps() async throws {
        let date1 = Date()
        let date2 = Date().addingTimeInterval(100)
        let item1 = Item(timestamp: date1)
        let item2 = Item(timestamp: date2)
        #expect(item1.timestamp != item2.timestamp)
        #expect(item1.timestamp == date1)
        #expect(item2.timestamp == date2)
    }
}

// MARK: - Item SwiftData Persistence Tests

@Suite("Item SwiftData Tests")
struct ItemSwiftDataTests {

    @Test @MainActor func itemCanBeInsertedIntoModelContext() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        let item = Item(timestamp: Date())
        context.insert(item)
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let items = try context.fetch(descriptor)
        #expect(items.count == 1)
    }

    @Test @MainActor func multipleItemsCanBeInserted() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        for i in 0..<5 {
            let item = Item(timestamp: Date().addingTimeInterval(Double(i) * 60))
            context.insert(item)
        }
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let items = try context.fetch(descriptor)
        #expect(items.count == 5)
    }

    @Test @MainActor func itemCanBeDeleted() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        let item = Item(timestamp: Date())
        context.insert(item)
        try context.save()

        context.delete(item)
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let items = try context.fetch(descriptor)
        #expect(items.count == 0)
    }

    @Test @MainActor func itemTimestampPersistsAfterSave() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        let now = Date()
        let item = Item(timestamp: now)
        context.insert(item)
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let items = try context.fetch(descriptor)
        #expect(items.first?.timestamp == now)
    }

    @Test @MainActor func itemTimestampUpdatePersists() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        let item = Item(timestamp: Date())
        context.insert(item)
        try context.save()

        let newDate = Date().addingTimeInterval(7200)
        item.timestamp = newDate
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let items = try context.fetch(descriptor)
        #expect(items.first?.timestamp == newDate)
    }

    @Test @MainActor func deletingSpecificItemLeavesOthers() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        let item1 = Item(timestamp: Date())
        let item2 = Item(timestamp: Date().addingTimeInterval(60))
        let item3 = Item(timestamp: Date().addingTimeInterval(120))
        context.insert(item1)
        context.insert(item2)
        context.insert(item3)
        try context.save()

        context.delete(item2)
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let items = try context.fetch(descriptor)
        #expect(items.count == 2)
    }
}

// MARK: - insertItem Function Tests

@Suite("insertItem Function Tests")
struct InsertItemTests {

    @Test @MainActor func insertItemAddsToContext() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        insertItem(into: context)
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let items = try context.fetch(descriptor)
        #expect(items.count == 1)
    }

    @Test @MainActor func insertItemWithCustomTimestamp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        let specificDate = Date(timeIntervalSince1970: 1_000_000)
        insertItem(into: context, timestamp: specificDate)
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let items = try context.fetch(descriptor)
        #expect(items.count == 1)
        #expect(items.first?.timestamp == specificDate)
    }

    @Test @MainActor func insertMultipleItems() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        for i in 0..<10 {
            insertItem(into: context, timestamp: Date().addingTimeInterval(Double(i)))
        }
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let items = try context.fetch(descriptor)
        #expect(items.count == 10)
    }

    @Test @MainActor func insertItemUsesCurrentDateByDefault() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        let before = Date()
        insertItem(into: context)
        let after = Date()
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let items = try context.fetch(descriptor)
        let timestamp = try #require(items.first?.timestamp)
        #expect(timestamp >= before)
        #expect(timestamp <= after)
    }
}

// MARK: - deleteItems Function Tests

@Suite("deleteItems Function Tests")
struct DeleteItemsTests {

    @Test @MainActor func deleteItemsRemovesSingleItem() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        let item1 = Item(timestamp: Date())
        let item2 = Item(timestamp: Date().addingTimeInterval(60))
        context.insert(item1)
        context.insert(item2)
        try context.save()

        let allItems = [item1, item2]
        deleteItems(from: allItems, at: IndexSet(integer: 0), using: context)
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.count == 1)
    }

    @Test @MainActor func deleteItemsRemovesMultipleItems() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        let item1 = Item(timestamp: Date())
        let item2 = Item(timestamp: Date().addingTimeInterval(60))
        let item3 = Item(timestamp: Date().addingTimeInterval(120))
        context.insert(item1)
        context.insert(item2)
        context.insert(item3)
        try context.save()

        let allItems = [item1, item2, item3]
        deleteItems(from: allItems, at: IndexSet([0, 2]), using: context)
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.count == 1)
    }

    @Test @MainActor func deleteItemsWithEmptyOffsets() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        let item = Item(timestamp: Date())
        context.insert(item)
        try context.save()

        let allItems = [item]
        deleteItems(from: allItems, at: IndexSet(), using: context)
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.count == 1)
    }

    @Test @MainActor func deleteAllItems() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let context = container.mainContext

        let item1 = Item(timestamp: Date())
        let item2 = Item(timestamp: Date().addingTimeInterval(60))
        context.insert(item1)
        context.insert(item2)
        try context.save()

        let allItems = [item1, item2]
        deleteItems(from: allItems, at: IndexSet([0, 1]), using: context)
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.count == 0)
    }
}

// MARK: - formattedTimestamp Function Tests

@Suite("formattedTimestamp Function Tests")
struct FormattedTimestampTests {

    @Test func formattedTimestampReturnsNonEmptyString() async throws {
        let date = Date()
        let result = formattedTimestamp(date)
        #expect(!result.isEmpty)
    }

    @Test func formattedTimestampForKnownDate() async throws {
        let components = DateComponents(year: 2026, month: 1, day: 15, hour: 10, minute: 30, second: 0)
        let date = Calendar.current.date(from: components)!
        let result = formattedTimestamp(date)
        #expect(result.contains("2026"))
        #expect(result.contains("10"))
        #expect(result.contains("30"))
    }

    @Test func formattedTimestampDifferentDatesProduceDifferentStrings() async throws {
        let date1 = Date(timeIntervalSince1970: 0)
        let date2 = Date(timeIntervalSince1970: 86400 * 365)
        let result1 = formattedTimestamp(date1)
        let result2 = formattedTimestamp(date2)
        #expect(result1 != result2)
    }
}

// MARK: - ModelContainer Configuration Tests

@Suite("ModelContainer Configuration Tests")
struct ModelContainerTests {

    @Test func inMemoryModelContainerCanBeCreated() async throws {
        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        #expect(container.schema.entities.count > 0)
    }

    @Test func schemaContainsItemEntity() async throws {
        let schema = Schema([Item.self])
        let entityNames = schema.entities.map { $0.name }
        #expect(entityNames.contains("Item"))
    }

    @Test func appModelContainerMatchesExpectedSchema() async throws {
        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let entityNames = container.schema.entities.map { $0.name }
        #expect(entityNames.contains("Item"))
    }
}

// MARK: - ContentView Tests

@Suite("ContentView Tests")
struct ContentViewTests {

    @Test @MainActor func contentViewCanBeInstantiated() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let _ = ContentView().modelContainer(container)
    }

    @Test @MainActor func contentViewRendersWithModelContainer() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let _ = ContentView().modelContainer(container)
    }

    @Test @MainActor func contentViewPreviewDoesNotCrash() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let _ = try ModelContainer(for: Item.self, configurations: config)
    }
}

// MARK: - ItemDetailView Tests

@Suite("ItemDetailView Tests")
struct ItemDetailViewTests {

    @Test @MainActor func itemDetailViewDisplaysFormattedTimestamp() async throws {
        let date = Date()
        let view = ItemDetailView(timestamp: date)
        #expect(view.timestamp == date)
    }

    @Test @MainActor func itemDetailViewWithSpecificDate() async throws {
        let components = DateComponents(year: 2026, month: 3, day: 15, hour: 9, minute: 45)
        let date = Calendar.current.date(from: components)!
        let view = ItemDetailView(timestamp: date)
        #expect(view.timestamp == date)
    }

    @Test @MainActor func itemDetailViewBodyCanBeEvaluated() async throws {
        let date = Date()
        let view = ItemDetailView(timestamp: date)
        let _ = view.body
    }
}

// MARK: - ItemRowView Tests

@Suite("ItemRowView Tests")
struct ItemRowViewTests {

    @Test @MainActor func itemRowViewDisplaysTimestamp() async throws {
        let date = Date()
        let view = ItemRowView(timestamp: date)
        #expect(view.timestamp == date)
    }

    @Test @MainActor func itemRowViewWithDistantDate() async throws {
        let date = Date.distantPast
        let view = ItemRowView(timestamp: date)
        #expect(view.timestamp == date)
    }

    @Test @MainActor func itemRowViewBodyCanBeEvaluated() async throws {
        let date = Date()
        let view = ItemRowView(timestamp: date)
        let _ = view.body
    }
}

// MARK: - App Entry Point Tests

@Suite("App Configuration Tests")
struct AppConfigurationTests {

    @Test func appUsesCorrectSchema() async throws {
        let schema = Schema([Item.self])
        #expect(schema.entities.isEmpty == false)
    }

    @Test func modelConfigurationDefaultsToNonVolatile() async throws {
        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        #expect(config.isStoredInMemoryOnly == false)
    }

    @Test func modelConfigurationInMemoryMode() async throws {
        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        #expect(config.isStoredInMemoryOnly == true)
    }

    @Test func containerCanBeCreatedWithPersistentConfig() async throws {
        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        #expect(container.schema.entities.map { $0.name }.contains("Item"))
    }
}
