import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MetalPriceViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        headerView
                        
                        metalTabsView
                        
                        priceCardView
                        
                        chartTabsView
                        
                        chartView
                        
                        infoCardView
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await viewModel.fetchAllPrices()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 4) {
            Text("贵金属价格追踪")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("上海期货交易所实时行情")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.bottom, 8)
    }
    
    private var metalTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MetalType.all, id: \.id) { metal in
                    MetalTabButton(
                        metal: metal,
                        isSelected: viewModel.selectedMetal.id == metal.id,
                        price: viewModel.prices[metal.id]
                    ) {
                        viewModel.selectMetal(metal)
                    }
                }
            }
        }
    }
    
    private var priceCardView: some View {
        VStack(spacing: 12) {
            if let price = viewModel.prices[viewModel.selectedMetal.id] {
                Text("\(viewModel.selectedMetal.icon) \(viewModel.selectedMetal.name)价格")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text(price.formattedPrice)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(Color(hex: "667eea"))
                
                Text(price.changeText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(price.isUp ? .green : (price.isDown ? .red : .gray))
                
                Text("更新于 \(price.formattedTime)")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                ProgressView()
                    .padding()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private var chartTabsView: some View {
        HStack(spacing: 8) {
            ForEach(MetalPriceViewModel.ChartType.allCases, id: \.self) { type in
                Button(action: { viewModel.selectChartType(type) }) {
                    Text(type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(viewModel.selectedChartType == type ? Color.white : Color.white.opacity(0.2))
                        .foregroundColor(viewModel.selectedChartType == type ? Color(hex: "667eea") : .white)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private var chartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(viewModel.selectedMetal.name)\(viewModel.selectedChartType.rawValue)")
                .font(.headline)
            
            if viewModel.klineData.isEmpty {
                ProgressView()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                ChartView(data: viewModel.klineData, chartType: viewModel.selectedChartType)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private var infoCardView: some View {
        let price = viewModel.prices[viewModel.selectedMetal.id]
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
            InfoItem(label: "今开", value: price.map { "¥\($0.open)" } ?? "--")
            InfoItem(label: "最高", value: price.map { "¥\($0.high)" } ?? "--")
            InfoItem(label: "最低", value: price.map { "¥\($0.low)" } ?? "--")
            InfoItem(label: "昨收", value: price.map { "¥\($0.closePrev)" } ?? "--")
            InfoItem(label: "成交量", value: price.map { "\($0.volume)" } ?? "--")
            InfoItem(label: "合约", value: price?.code ?? "--")
            InfoItem(label: "货币", value: price?.currency ?? "CNY")
            InfoItem(label: "单位", value: viewModel.selectedMetal.unit)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

struct MetalTabButton: View {
    let metal: MetalType
    let isSelected: Bool
    let price: MetalPrice?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(metal.icon)
                    .font(.title2)
                Text(metal.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                if let price = price {
                    Text("¥\(String(format: "%.2f", price.price))")
                        .font(.caption2)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isSelected ? Color.white : Color.white.opacity(0.2))
            .foregroundColor(isSelected ? Color(hex: "667eea") : .white)
            .cornerRadius(12)
        }
    }
}

struct InfoItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}
