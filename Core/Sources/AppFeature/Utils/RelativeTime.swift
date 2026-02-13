import Foundation

public enum RelativeTime {
    public static func string(from date: Date, now: Date = Date()) -> String {
        let diffInSeconds = Int(now.timeIntervalSince(date))
        if diffInSeconds < 0 { return "now" }

        if diffInSeconds < 5 { return "now" }
        if diffInSeconds < 60 { return "\(diffInSeconds) secs ago" }

        let diffInMinutes = diffInSeconds / 60
        if diffInMinutes < 60 { return "\(diffInMinutes) \(diffInMinutes == 1 ? "min" : "mins") ago" }

        let diffInHours = diffInMinutes / 60
        if diffInHours < 24 { return "\(diffInHours) \(diffInHours == 1 ? "hr" : "hrs") ago" }

        let diffInDays = diffInHours / 24
        if diffInDays < 7 { return "\(diffInDays) \(diffInDays == 1 ? "day" : "days") ago" }

        if diffInDays < 30 {
            let diffInWeeks = diffInDays / 7
            return "\(diffInWeeks) \(diffInWeeks == 1 ? "week" : "weeks") ago"
        }

        let diffInMonths = diffInDays / 30
        if diffInMonths < 12 {
            return "\(diffInMonths) \(diffInMonths == 1 ? "month" : "months") ago"
        }

        let diffInYears = diffInMonths / 12
        return "\(diffInYears) \(diffInYears == 1 ? "year" : "years") ago"
    }
}

