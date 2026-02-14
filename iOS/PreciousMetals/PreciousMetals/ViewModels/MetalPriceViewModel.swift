import Foundation
import SwiftUI

@MainActor
class MetalPriceViewModel: ObservableObject {
    @Published var prices: [String: MetalPrice] = [:]
    @Published var klineData: [KLineData] = []
    @Published var selectedMetal: MetalType = .gold
    @Published var selectedChartType: ChartType = .daily
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    enum ChartType: String, CaseIterable {
        case daily = "日K线"
        case monthly = "月K线"
        case today = "今日走势"
        
        var days: Int {
            switch self {
            case .daily: return 60
            case .monthly: return 365
            case .today: return 1
            }
        }
        
        var klt: Int {
            switch self {
            case .daily, .monthly: return 101
            case .today: return 60
            }
        }
    }
    
    func fetchAllPrices() async {
        isLoading = true
        errorMessage = nil
        
        async let gold = MetalPriceService.shared.fetchPrice(metal: .gold)
        async let silver = MetalPriceService.shared.fetchPrice(metal: .silver)
        async let platinum = MetalPriceService.shared.fetchPrice(metal: .platinum)
        async let palladium = MetalPriceService.shared.fetchPrice(metal: .palladium)
        
        do {
            let results = try await [gold, silver, platinum, palladium]
            for (index, price) in results.enumerated() {
                let metal = MetalType.all[index]
                prices[metal.id] = price
            }
            await fetchKLine()
        } catch {
            errorMessage = "获取数据失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func fetchKLine() async {
        do {
            klineData = try await MetalPriceService.shared.fetchKLine(
                metal: selectedMetal,
                klt: selectedChartType.klt,
                days: selectedChartType.days
            )
        } catch {
            print("Failed to fetch kline: \(error)")
        }
    }
    
    func selectMetal(_ metal: MetalType) {
        selectedMetal = metal
        Task {
            await fetchKLine()
        }
    }
    
    func selectChartType(_ type: ChartType) {
        selectedChartType = type
        Task {
            await fetchKLine()
        }
    }
    
    func refresh() async {
        await fetchAllPrices()
    }
}
