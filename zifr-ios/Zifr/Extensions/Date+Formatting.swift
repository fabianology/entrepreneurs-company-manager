import Foundation

extension Date {
    func timeAgoDisplay() -> String {
        let now = Date()
        let diff = now.timeIntervalSince(self)
        let hours = Int(diff / 3600)
        let days = Int(diff / 86400)

        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if hours < 24 { return "\(hours)h ago" }
        return "\(days)d ago"
    }

    var shortDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: self)
    }

    var numericDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yy"
        return f.string(from: self)
    }
}

extension Double {
    var currencyString: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return "$\(f.string(from: NSNumber(value: self)) ?? "0.00")"
    }
}
import Foundation

extension String {
    var withOrdinal: String {
        let components = self.components(separatedBy: " ")
        guard let last = components.last, let number = Int(last) else {
            return self
        }
        
        let tens = (number % 100) / 10
        let suffix: String
        if tens == 1 {
            suffix = "th"
        } else {
            switch number % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        
        let ordinalString = "\(number)\(suffix)"
        
        if components.count > 1 {
            let prefix = components.dropLast().joined(separator: " ")
            return "\(prefix) \(ordinalString)"
        } else {
            return ordinalString
        }
    }
}
