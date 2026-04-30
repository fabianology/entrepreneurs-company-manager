import Foundation
import SwiftUI

struct TickerItem: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let label: String
    let price: Double
    let changePercent: Double
}

@Observable
class TickerService {
    var tickers: [TickerItem] = []
    var isLoading = false
    
    private let apiKey = "RZ809AQRM7WN5C3I"
    private let symbols = [
        ("SPY", "S&P 500"),
        ("QQQ", "NASDAQ"),
        ("AAPL", "Apple"),
        ("NVDA", "Nvidia"),
        ("TSLA", "Tesla")
    ]
    
    func fetchTickers() async {
        guard tickers.isEmpty else { return }
        
        await MainActor.run { isLoading = true }
        
        var fetchedItems: [TickerItem] = []
        
        for (symbol, label) in symbols {
            guard let url = URL(string: "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(apiKey)") else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let quote = json["Global Quote"] as? [String: Any],
                   let priceStr = quote["05. price"] as? String,
                   let changePctStr = quote["10. change percent"] as? String,
                   let price = Double(priceStr),
                   let changePct = Double(changePctStr.replacingOccurrences(of: "%", with: "")) {
                    
                    fetchedItems.append(TickerItem(
                        symbol: symbol,
                        label: label,
                        price: price,
                        changePercent: changePct
                    ))
                }
            } catch {
                print("Failed to fetch \(symbol): \(error)")
            }
        }
        
        await MainActor.run {
            // If Alpha Vantage rate limited us (they have a 25/day and 5/min cap on free tier), fallback to mock data completely
            if fetchedItems.count == symbols.count {
                self.tickers = fetchedItems
            } else {
                self.tickers = generateMockData()
            }
            self.isLoading = false
        }
    }

    private func generateMockData() -> [TickerItem] {
        return [
            TickerItem(symbol: "SPY", label: "S&P 500", price: 520.34, changePercent: 1.2),
            TickerItem(symbol: "QQQ", label: "NASDAQ", price: 440.84, changePercent: 1.5),
            TickerItem(symbol: "AAPL", label: "Apple", price: 173.13, changePercent: 0.8),
            TickerItem(symbol: "NVDA", label: "Nvidia", price: 880.00, changePercent: 2.4),
            TickerItem(symbol: "TSLA", label: "Tesla", price: 170.21, changePercent: -3.1)
        ]
    }
}
