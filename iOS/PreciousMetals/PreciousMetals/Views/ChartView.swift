import SwiftUI
import Charts

struct ChartView: View {
    let data: [KLineData]
    let chartType: MetalPriceViewModel.ChartType
    
    var body: some View {
        if #available(iOS 16.0, *) {
            if chartType == .today {
                lineChart
            } else {
                candlestickChart
            }
        } else {
            simpleLineChart
        }
    }
    
    @available(iOS 16.0, *)
    private var lineChart: some View {
        Chart(data) { item in
            LineMark(
                x: .value("时间", formatTime(item.timestamp)),
                y: .value("价格", item.price)
            )
            .foregroundStyle(Color(hex: "667eea"))
            .interpolationMethod(.catmullRom)
            
            AreaMark(
                x: .value("时间", formatTime(item.timestamp)),
                y: .value("价格", item.price)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "667eea").opacity(0.3), Color(hex: "667eea").opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text("¥\(String(format: "%.0f", price))")
                    }
                }
            }
        }
        .chartYScale(domain: yAxisDomain)
    }
    
    @available(iOS 16.0, *)
    private var candlestickChart: some View {
        Chart(data) { item in
            RectangleMark(
                x: .value("日期", formatDate(item.timestamp)),
                yStart: .value("低", item.low),
                yEnd: .value("高", item.high)
            )
            .foregroundStyle(item.price >= item.open ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
            
            RectangleMark(
                x: .value("日期", formatDate(item.timestamp)),
                yStart: .value("开盘", min(item.open, item.price)),
                yEnd: .value("收盘", max(item.open, item.price))
            )
            .foregroundStyle(item.price >= item.open ? Color.green : Color.red)
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text("¥\(String(format: "%.0f", price))")
                    }
                }
            }
        }
        .chartYScale(domain: yAxisDomain)
    }
    
    private var simpleLineChart: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let maxPrice = data.map(\.price).max() ?? 1
                let minPrice = data.map(\.price).min() ?? 0
                let range = maxPrice - minPrice
                
                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let padding: CGFloat = 20
                
                for (index, item) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height - padding - CGFloat((item.price - minPrice) / range) * (geometry.size.height - 2 * padding)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color(hex: "667eea"), lineWidth: 2)
        }
    }
    
    private var yAxisDomain: ClosedRange<Double> {
        guard !data.isEmpty else { return 0...100 }
        let prices = data.flatMap { [$0.high, $0.low] }
        let min = prices.min() ?? 0
        let max = prices.max() ?? 100
        let padding = (max - min) * 0.1
        return (min - padding)...(max + padding)
    }
    
    private func formatTime(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}
