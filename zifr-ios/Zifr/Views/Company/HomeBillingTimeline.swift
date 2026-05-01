import SwiftUI

struct BillingTimelineView: View {
    let subscriptions: [Subscription]

    private let calendar = Calendar.current
    private let subsColor = Color(hex: "#2070BD")

    // 14-day window: 7 past + today + 6 future
    private var days: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (-7...6).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    private var today: Date { calendar.startOfDay(for: Date()) }

    // Map day-of-month → subscriptions due that day
    private func subs(for date: Date) -> [Subscription] {
        let dayOfMonth = calendar.component(.day, from: date)
        return subscriptions.filter { sub in
            guard let nextRenewal = sub.nextRenewal, let renewal = HomeRenewalParser.parse(nextRenewal) else { return false }
            return calendar.component(.day, from: renewal) == dayOfMonth
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        dayColumn(day)
                            .id(day)
                    }
                }
                .padding(.horizontal, 14)
            }
            .onAppear {
                withAnimation { proxy.scrollTo(today, anchor: .center) }
            }
        }
    }

    // MARK: – Day Column

    private func dayColumn(_ date: Date) -> some View {
        let isToday = calendar.isDate(date, inSameDayAs: Date())
        let dueSubs  = subs(for: date)
        let isPast   = date < today

        return VStack(spacing: 4) {
            // Day-of-week
            Text(dayOfWeek(date))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isToday ? subsColor : Color.white.opacity(isPast ? 0.2 : 0.4))
                .tracking(0.3)

            // Day number pill
            ZStack {
                if isToday {
                    Circle().fill(subsColor)
                        .frame(width: 26, height: 26)
                } else {
                    Circle().fill(Color.clear)
                        .frame(width: 26, height: 26)
                }
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: isToday ? .black : .medium))
                    .foregroundStyle(isToday ? .white : (isPast ? Color.white.opacity(0.25) : Color.white.opacity(0.8)))
            }

            // Subscription avatars (up to 2 + overflow badge)
            if dueSubs.isEmpty {
                Spacer().frame(height: 20)
            } else {
                VStack(spacing: 3) {
                    ForEach(Array(dueSubs.prefix(2))) { sub in
                        subAvatar(sub, muted: isPast)
                    }
                    if dueSubs.count > 2 {
                        Text("+\(dueSubs.count - 2)")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(subsColor)
                            .frame(width: 22, height: 14)
                            .background(subsColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(width: 36)
    }

    private func subAvatar(_ sub: Subscription, muted: Bool) -> some View {
        ZStack {
            Circle()
                .fill(brandColor(sub.name).opacity(muted ? 0.3 : 0.85))
                .frame(width: 22, height: 22)
            Text(sub.name.prefix(1).uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white.opacity(muted ? 0.5 : 1))
        }
    }

    // MARK: – Helpers

    private func dayOfWeek(_ date: Date) -> String {
        let idx = calendar.component(.weekday, from: date) - 1 // 0=Sun
        return ["SU","MO","TU","WE","TH","FR","SA"][safe: idx] ?? ""
    }

    private func brandColor(_ name: String) -> Color {
        // Simple deterministic hue from name hash
        let hash = abs(name.unicodeScalars.reduce(0) { ($0 << 5) &+ $0 &+ Int($1.value) })
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
    }
}

// MARK: - Safe subscript helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
