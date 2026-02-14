import Foundation

struct MetalType: Identifiable, CaseIterable {
    let id: String
    let name: String
    let secid: String
    let unit: String
    let icon: String
    
    static let gold = MetalType(id: "gold", name: "黄金", secid: "113.AU2606", unit: "g", icon: "🥇")
    static let silver = MetalType(id: "silver", name: "白银", secid: "113.AG2606", unit: "kg", icon: "🥈")
    static let platinum = MetalType(id: "platinum", name: "铂金", secid: "113.SP2606", unit: "g", icon: "⚪")
    static let palladium = MetalType(id: "palladium", name: "钯金", secid: "113.PD2606", unit: "g", icon: "🔵")
    
    static let all: [MetalType] = [.gold, .silver, .platinum, .palladium]
}

struct MetalPrice: Codable {
    let timestamp: Int64
    let price: Double
    let priceChange: Double
    let priceChangePercent: Double
    let currency: String
    let unit: String
    let high: Double
    let low: Double
    let open: Double
    let closePrev: Double
    let volume: Int
    let code: String
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case price
        case priceChange = "price_change"
        case priceChangePercent = "price_change_percent"
        case currency
        case unit
        case high
        case low
        case open
        case closePrev = "close_prev"
        case volume
        case code
        case name
    }
    
    var isUp: Bool {
        priceChange > 0
    }
    
    var isDown: Bool {
        priceChange < 0
    }
    
    var changeText: String {
        if priceChange > 0 {
            return String(format: "↑ +%.2f (+%.2f%%)", priceChange, priceChangePercent)
        } else if priceChange < 0 {
            return String(format: "↓ %.2f (%.2f%%)", priceChange, priceChangePercent)
        } else {
            return "→ 0.00 (0.00%)"
        }
    }
    
    var formattedPrice: String {
        String(format: "¥%.2f", price)
    }
    
    var formattedTime: String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct KLineData: Codable {
    let timestamp: Int64
    let date: String
    let price: Double
    let open: Double
    let high: Double
    let low: Double
    let volume: Int
    let priceChangePercent: Double
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case date
        case price
        case open
        case high
        case low
        case volume
        case priceChangePercent = "price_change_percent"
    }
}
