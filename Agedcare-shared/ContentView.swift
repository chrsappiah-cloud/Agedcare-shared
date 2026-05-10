//
//  ContentView.swift
//  Agedcare-shared
//
//  Created by Christopher Appiah-Thompson  on 10/5/2026.
//

import SwiftUI
import SwiftData

func insertItem(into context: ModelContext, timestamp: Date = Date()) {
    withAnimation {
        let newItem = Item(timestamp: timestamp)
        context.insert(newItem)
    }
}

func deleteItems(from items: [Item], at offsets: IndexSet, using context: ModelContext) {
    withAnimation {
        for index in offsets {
            context.delete(items[index])
        }
    }
}

func formattedTimestamp(_ date: Date) -> String {
    date.formatted(date: .numeric, time: .standard)
}

struct ItemDetailView: View {
    let timestamp: Date

    var body: some View {
        Text("Item at \(formattedTimestamp(timestamp))")
            .font(.title2)
            .navigationTitle("Item Detail")
    }
}

struct ItemRowView: View {
    let timestamp: Date

    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundStyle(.blue)
            Text(timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Items Yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Tap the + button to add your first item.")
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            NavigationLink {
                                ItemDetailView(timestamp: item.timestamp)
                            } label: {
                                ItemRowView(timestamp: item.timestamp)
                            }
                        }
                        .onDelete { offsets in
                            deleteItems(from: items, at: offsets, using: modelContext)
                        }
                    }
                }
            }
            .navigationTitle("Agedcare Items")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: { insertItem(into: modelContext) }) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
