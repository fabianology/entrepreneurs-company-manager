import Foundation

enum HomeRenewalParser {
    static func parse(_ dateStr: String) -> Date? {
        if dateStr.isEmpty { return nil }
        let formatter = DateFormatter()
        
        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MMM d, yyyy",
            "MMM dd, yyyy",
            "MM-dd-yyyy"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let d = formatter.date(from: dateStr) { return d }
        }
        
        // Handle "Every Xth"
        if dateStr.lowercased().contains("every") || dateStr.lowercased().contains("th") {
            let digits = dateStr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let day = Int(digits), day > 0, day <= 31 {
                var comps = Calendar.current.dateComponents([.year, .month], from: Date())
                comps.day = day
                if let d = Calendar.current.date(from: comps) {
                    if d < Date() {
                        comps.month = (comps.month ?? 1) + 1
                        return Calendar.current.date(from: comps)
                    }
                    return d
                }
            }
        }
        return nil
    }
}
