import WidgetKit
import SwiftUI

struct MetalPriceEntry: TimelineEntry {
    let date: Date
    let prices: [MetalPriceData]
}

struct MetalPriceData {
    let metal: String
    let icon: String
    let price: Double
    let change: Double
    let changePercent: Double
    
    var isUp: Bool { change > 0 }
    var isDown: Bool { change < 0 }
    
    var formattedPrice: String {
        String(format: "¥%.2f", price)
    }
    
    var formattedChange: String {
        if change > 0 {
            return String(format: "+%.2f", change)
        } else {
            return String(format: "%.2f", change)
        }
    }
}

struct MetalPriceProvider: IntentTimelineProvider {
    typealias Entry = MetalPriceEntry
    typealias Intent = SelectMetalIntent
    
    func placeholder(in context: Context) -> MetalPriceEntry {
        MetalPriceEntry(
            date: Date(),
            prices: [
                MetalPriceData(metal: "黄金", icon: "🥇", price: 1113.46, change: -17.74, changePercent: -1.57),
                MetalPriceData(metal: "白银", icon: "🥈", price: 195.70, change: -10.44, changePercent: -5.06)
            ]
        )
    }
    
    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (MetalPriceEntry) -> Void) {
        let entry = placeholder(in: context)
        completion(entry)
    }
    
    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<MetalPriceEntry>) -> Void) {
        Task {
            var prices: [MetalPriceData] = []
            
            async let goldPrice = fetchPrice(secid: "113.AU2606", name: "黄金", icon: "🥇")
            async let silverPrice = fetchPrice(secid: "113.AG2606", name: "白银", icon: "🥈")
            
            let results = await [goldPrice, silverPrice]
            prices = results.compactMap { $0 }
            
            let entry = MetalPriceEntry(date: Date(), prices: prices)
            
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            
            completion(timeline)
        }
    }
    
    private func fetchPrice(secid: String, name: String, icon: String) async -> MetalPriceData? {
        let fields = "f43,f169,f170"
        let urlString = "https://push2.eastmoney.com/api/qt/stock/get?secid=\(secid)&fields=\(fields)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            request.setValue("https://quote.eastmoney.com/", forHTTPHeaderField: "Referer")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["rc"] as? Int == 0,
                  let rawData = json["data"] as? [String: Any] else {
                return nil
            }
            
            let price = Double(rawData["f43"] as? Int ?? 0) / 100.0
            let change = Double(rawData["f169"] as? Int ?? 0) / 100.0
            let changePercent = Double(rawData["f170"] as? Int ?? 0) / 100.0
            
            return MetalPriceData(metal: name, icon: icon, price: price, change: change, changePercent: changePercent)
        } catch {
            return nil
        }
    }
}

struct SelectMetalIntent: Intent {
    static var title: LocalizedStringResource = "选择贵金属"
    
    @Parameter(title: "贵金属类型")
    var metalType: String?
}

struct PreciousMetalsWidgetEntryView: View {
    var entry: MetalPriceEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            mediumWidget
        }
    }
    
    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let price = entry.prices.first {
                HStack {
                    Text(price.icon)
                        .font(.title2)
                    Text(price.metal)
                        .font(.headline)
                }
                
                Text(price.formattedPrice)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(price.formattedChange)
                    .font(.subheadline)
                    .foregroundColor(price.isUp ? .green : (price.isDown ? .red : .gray))
            }
            
            Spacer()
            
            Text("更新于 \(entry.date.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
    }
    
    private var mediumWidget: some View {
        VStack(spacing: 12) {
            HStack {
                Text("贵金属价格")
                    .font(.headline)
                Spacer()
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ForEach(entry.prices.prefix(2), id: \.metal) { price in
                HStack {
                    Text(price.icon)
                        .font(.title3)
                    Text(price.metal)
                        .font(.subheadline)
                        .frame(width: 40, alignment: .leading)
                    
                    Spacer()
                    
                    Text(price.formattedPrice)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(price.formattedChange)
                        .font(.caption)
                        .foregroundColor(price.isUp ? .green : (price.isDown ? .red : .gray))
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
        .padding()
    }
    
    private var largeWidget: some View {
        VStack(spacing: 12) {
            HStack {
                Text("贵金属价格追踪")
                    .font(.headline)
                Spacer()
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ForEach(entry.prices, id: \.metal) { price in
                HStack {
                    Text(price.icon)
                        .font(.title2)
                    Text(price.metal)
                        .font(.subheadline)
                        .frame(width: 50, alignment: .leading)
                    
                    Spacer()
                    
                    Text(price.formattedPrice)
                        .font(.headline)
                    
                    Text(price.formattedChange)
                        .font(.subheadline)
                        .foregroundColor(price.isUp ? .green : (price.isDown ? .red : .gray))
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PreciousMetalsWidget: Widget {
    let kind: String = "PreciousMetalsWidget"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: SelectMetalIntent.self,
            provider: MetalPriceProvider()
        ) { entry in
            PreciousMetalsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("贵金属价格")
        .description("实时追踪黄金、白银等贵金属价格")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetPreview: PreviewProvider {
    static var previews: some View {
        Group {
            PreciousMetalsWidgetEntryView(entry: MetalPriceEntry(
                date: Date(),
                prices: [
                    MetalPriceData(metal: "黄金", icon: "🥇", price: 1113.46, change: -17.74, changePercent: -1.57),
                    MetalPriceData(metal: "白银", icon: "🥈", price: 195.70, change: -10.44, changePercent: -5.06)
                ]
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            PreciousMetalsWidgetEntryView(entry: MetalPriceEntry(
                date: Date(),
                prices: [
                    MetalPriceData(metal: "黄金", icon: "🥇", price: 1113.46, change: -17.74, changePercent: -1.57),
                    MetalPriceData(metal: "白银", icon: "🥈", price: 195.70, change: -10.44, changePercent: -5.06)
                ]
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            PreciousMetalsWidgetEntryView(entry: MetalPriceEntry(
                date: Date(),
                prices: [
                    MetalPriceData(metal: "黄金", icon: "🥇", price: 1113.46, change: -17.74, changePercent: -1.57),
                    MetalPriceData(metal: "白银", icon: "🥈", price: 195.70, change: -10.44, changePercent: -5.06)
                ]
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
