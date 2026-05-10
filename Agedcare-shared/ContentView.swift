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
    }
}

struct ItemRowView: View {
    let timestamp: Date

    var body: some View {
        Text(timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
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
        } detail: {
            Text("Select an item")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
