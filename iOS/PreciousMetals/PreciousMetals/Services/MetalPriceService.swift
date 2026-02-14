import Foundation

class MetalPriceService {
    static let shared = MetalPriceService()
    
    private let baseURL = "https://push2.eastmoney.com/api/qt/stock/get"
    private let klineBaseURL = "https://push2his.eastmoney.com/api/qt/stock/kline/get"
    
    private init() {}
    
    func fetchPrice(metal: MetalType) async throws -> MetalPrice {
        let fields = "f43,f44,f45,f46,f47,f48,f49,f50,f51,f52,f57,f58,f60,f107,f116,f117,f152,f168,f169,f170,f171,f161,f162,f163,f164,f165,f166,f167"
        let urlString = "\(baseURL)?secid=\(metal.secid)&fields=\(fields)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("https://quote.eastmoney.com/", forHTTPHeaderField: "Referer")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["rc"] as? Int == 0,
              let rawData = json["data"] as? [String: Any] else {
            throw URLError(.cannotDecodeContentData)
        }
        
        let price = rawData["f43"] as? Int ?? 0
        let priceChange = rawData["f169"] as? Int ?? 0
        let priceChangePercent = rawData["f170"] as? Int ?? 0
        let closePrev = Double(price - priceChange) / 100.0
        
        let metalPrice = MetalPrice(
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            price: Double(price) / 100.0,
            priceChange: Double(priceChange) / 100.0,
            priceChangePercent: Double(priceChangePercent) / 100.0,
            currency: "CNY",
            unit: metal.unit,
            high: Double(rawData["f44"] as? Int ?? 0) / 100.0,
            low: Double(rawData["f45"] as? Int ?? 0) / 100.0,
            open: Double(rawData["f46"] as? Int ?? 0) / 100.0,
            closePrev: closePrev,
            volume: rawData["f49"] as? Int ?? 0,
            code: rawData["f57"] as? String ?? "",
            name: metal.name
        )
        
        return metalPrice
    }
    
    func fetchKLine(metal: MetalType, klt: Int, days: Int) async throws -> [KLineData] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let endStr = formatDate(endDate, format: "yyyyMMdd")
        let startStr = formatDate(startDate, format: "yyyyMMdd")
        
        let urlString = "\(klineBaseURL)?secid=\(metal.secid)&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58&klt=\(klt)&fqt=1&beg=\(startStr)&end=\(endStr)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("https://quote.eastmoney.com/", forHTTPHeaderField: "Referer")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["rc"] as? Int == 0,
              let rawData = json["data"] as? [String: Any],
              let klines = rawData["klines"] as? [String] else {
            return []
        }
        
        var result: [KLineData] = []
        for kline in klines {
            let parts = kline.split(separator: ",").map { String($0) }
            if parts.count >= 8 {
                let dateStr = parts[0]
                let timestamp = parseTimestamp(dateStr)
                
                let klineData = KLineData(
                    timestamp: timestamp,
                    date: dateStr,
                    price: Double(parts[2]) ?? 0,
                    open: Double(parts[1]) ?? 0,
                    high: Double(parts[3]) ?? 0,
                    low: Double(parts[4]) ?? 0,
                    volume: Int(parts[5]) ?? 0,
                    priceChangePercent: Double(parts[7]) ?? 0
                )
                result.append(klineData)
            }
        }
        
        return result
    }
    
    private func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    private func parseTimestamp(_ dateStr: String) -> Int64 {
        let formatter = DateFormatter()
        if dateStr.contains(" ") {
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
        } else {
            formatter.dateFormat = "yyyy-MM-dd"
        }
        guard let date = formatter.date(from: dateStr) else {
            return 0
        }
        return Int64(date.timeIntervalSince1970 * 1000)
    }
}
