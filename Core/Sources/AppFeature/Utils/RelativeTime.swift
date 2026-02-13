import Foundation

public enum RelativeTime {
    public static func string(from date: Date, now: Date = Date()) -> String {
        let diffInSeconds = Int(now.timeIntervalSince(date))
        if diffInSeconds < 0 { return "now" }

        if diffInSeconds < 5 { return "now" }
        if diffInSeconds < 60 { return "\(diffInSeconds)s" }

        let diffInMinutes = diffInSeconds / 60
        if diffInMinutes < 60 { return "\(diffInMinutes)m" }

        let diffInHours = diffInMinutes / 60
        if diffInHours < 24 { return "\(diffInHours)h" }

        let diffInDays = diffInHours / 24
        if diffInDays < 7 { return "\(diffInDays)d" }

        if diffInDays < 30 {
            let diffInWeeks = diffInDays / 7
            return "\(diffInWeeks)w"
        }

        let diffInMonths = diffInDays / 30
        if diffInMonths < 12 {
            return "\(diffInMonths)mo"
        }

        let diffInYears = diffInMonths / 12
        return "\(diffInYears)y"
    }
}

