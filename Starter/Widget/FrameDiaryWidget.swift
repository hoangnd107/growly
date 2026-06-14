import WidgetKit
import SwiftUI

struct FrameDiaryEntry: TimelineEntry {
    let date: Date
}

struct FrameDiaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> FrameDiaryEntry { FrameDiaryEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (FrameDiaryEntry) -> Void) {
        completion(FrameDiaryEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FrameDiaryEntry>) -> Void) {
        let entry = FrameDiaryEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60*60)))
        completion(timeline)
    }
}

struct FrameDiaryWidgetEntryView : View {
    var entry: FrameDiaryProvider.Entry
    var body: some View {
        Text("Frame Diary")
            .font(.headline)
            .padding()
    }
}

@main
struct FrameDiaryWidget: Widget {
    let kind: String = "FrameDiaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FrameDiaryProvider()) { entry in
            FrameDiaryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Frame Diary")
        .description("Shows your latest frame diary entry.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
