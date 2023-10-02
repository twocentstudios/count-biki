import SwiftUI

struct PlanningTopicsView: View {
    var body: some View {
        List {
            Section {
                Text("No favorites yet. Add one?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } header: {
                Text("Favorites \(Image(systemName: "star"))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            } footer: {
                Text("Tip: tap and hold a topic to add/remove a favorite")
            }

            Section {
                Text("Topics you've studied will appear here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } header: {
                Text("Recent \(Image(systemName: "eyes"))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }

            Section {
                NavigationLink {
                    List {
                        CellView(title: "Absolute Beginner", subtitle: "Whole numbers 0-10")
                        CellView(title: "Beginner", subtitle: "Whole numbers 0-100")
                        CellView(title: "Intermediate", subtitle: "Whole numbers 0-1,000")
                        CellView(title: "Advanced", subtitle: "Whole numbers 0-10,000")
                        CellView(title: "Extreme", subtitle: "Whole numbers 0-1,000,000,000")
                    }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Numbers \(Image(systemName: "number.circle"))")
                                .font(.headline)
                        }
                    }
                } label: { CellView(title: "Numbers", subtitle: "Just whole numbers") }

                NavigationLink {
                    List {
                        CellView(title: "Conbini", subtitle: "Yen amounts 100-1500")
                        CellView(title: "Restaurant", subtitle: "Yen amounts 800-6000 by 10s")
                        CellView(title: "Monthly Rent", subtitle: "Yen amounts 50,000-200,000 by 1,000s")
                        CellView(title: "Annual Salary", subtitle: "Yen amounts 2,000,000-15,000,000 by 100,000s")
                    }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Money \(Image(systemName: "yensign.circle"))")
                                .font(.headline)
                        }
                    }
                } label: { CellView(title: "Money", subtitle: "Using money in common situations") }

                NavigationLink {
                    List {
                        CellView(title: "Hours", subtitle: "1-48時間 (including 半)")
                        CellView(title: "Minutes", subtitle: "1-100分間")
                        CellView(title: "Seconds", subtitle: "1-100秒間")
                        CellView(title: "Hours/Minutes", subtitle: "e.g. 24時間60分")
                        CellView(title: "Hours/Minutes/Seconds", subtitle: "e.g. 24時間60分60秒")
                        CellView(title: "Days", subtitle: "1-100日(間)")
                        CellView(title: "Weeks", subtitle: "1-50週間")
                        CellView(title: "Months", subtitle: "1-12か月 (including 半)")
                        CellView(title: "Years", subtitle: "1-100年間 (including 半)")
                    }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Time Durations \(Image(systemName: "clock.circle"))")
                                .font(.headline)
                        }
                    }
                } label: { CellView(title: "Time Durations", subtitle: "Lengths of time from seconds to years") }

                NavigationLink {
                    List {
                        CellView(title: "Hour (24-hour)", subtitle: "e.g. 20:00")
                        CellView(title: "Hour/Minute (24-hour)", subtitle: "e.g. 14:45")
                        CellView(title: "Hour (AM/PM)", subtitle: "e.g. 午後8時")
                        CellView(title: "Hours/Minute (AM/PM)", subtitle: "e.g. 午後2時45分")
                        CellView(title: "Day (Beginner)", subtitle: "1日-10日")
                        CellView(title: "Day (All)", subtitle: "1日-31日")
                        CellView(title: "Month", subtitle: "1月-12月")
                        CellView(title: "Year (Recent)", subtitle: "1970年-2030年")
                        CellView(title: "Year (A.D.)", subtitle: "1年-2500年")
                        CellView(title: "Year (Japanese Era)", subtitle: "明治/大正/昭和/平成/令和")
                        CellView(title: "Year/Month/Day (Recent)", subtitle: "e.g. 2017年9月30日")
                        CellView(title: "Year/Month/Day/Hour/Minute (Recent, 24-hour)", subtitle: "e.g. 2017年9月30日 17:05")
                    }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Dates & Times \(Image(systemName: "calendar.circle"))")
                                .font(.headline)
                        }
                    }
                } label: { CellView(title: "Dates & Times", subtitle: "Dates on a calendar") }
            } header: {
                Text("Listening \(Image(systemName: "ear"))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            } footer: {
                Text("Listen to a clip and transcribe the number")
            }

            Section {
                NavigationLink {
                    List {
                        CellView(title: "", subtitle: "")
                    }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Counters \(Image(systemName: "baseball"))")
                                .font(.headline)
                        }
                    }
                } label: { CellView(title: "Counters", subtitle: "Objects and more: 個、枚、人、...") }

                NavigationLink {
                    List {
                        CellView(title: "Hours", subtitle: "1-48時間 (including 半)")
                        CellView(title: "Minutes", subtitle: "1-100分間")
                        CellView(title: "Seconds", subtitle: "1-100秒間")
                        CellView(title: "Hours/Minutes", subtitle: "e.g. 24時間60分")
                        CellView(title: "Hours/Minutes/Seconds", subtitle: "e.g. 24時間60分60秒")
                        CellView(title: "Days", subtitle: "1-100日(間)")
                        CellView(title: "Weeks", subtitle: "1-50週間")
                        CellView(title: "Months", subtitle: "1-12か月 (including 半)")
                        CellView(title: "Years", subtitle: "1-100年間 (including 半)")
                    }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Time Durations \(Image(systemName: "clock.circle"))")
                                .font(.headline)
                        }
                    }
                } label: { CellView(title: "Time Durations", subtitle: "Lengths of time from seconds to years") }

                NavigationLink {
                    List {
                        CellView(title: "Hour (24-hour)", subtitle: "e.g. 20:00")
                        CellView(title: "Hour/Minute (24-hour)", subtitle: "e.g. 14:45")
                        CellView(title: "Hour (AM/PM)", subtitle: "e.g. 午後8時")
                        CellView(title: "Hours/Minute (AM/PM)", subtitle: "e.g. 午後2時45分")
                        CellView(title: "Day (Beginner)", subtitle: "1日-10日")
                        CellView(title: "Day (All)", subtitle: "1日-31日")
                        CellView(title: "Month", subtitle: "1月-12月")
                        CellView(title: "Year (Recent)", subtitle: "1970年-2030年")
                        CellView(title: "Year (A.D.)", subtitle: "1年-2500年")
                        CellView(title: "Year (Japanese Era)", subtitle: "明治/大正/昭和/平成/令和")
                        CellView(title: "Year/Month/Day (Recent)", subtitle: "e.g. 2017年9月30日")
                        CellView(title: "Year/Month/Day/Hour/Minute (Recent, 24-hour)", subtitle: "e.g. 2017年9月30日 17:05")
                    }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Dates & Times \(Image(systemName: "calendar.circle"))")
                                .font(.headline)
                        }
                    }
                } label: { CellView(title: "Dates & Times", subtitle: "Dates on a calendar") }
            } header: {
                Text("Reading \(Image(systemName: "book"))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            } footer: {
                Text("Read a phrase and transcribe the hiragana")
            }
        }
        .listStyle(.automatic)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Topics")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Topics")
                    .font(.headline)
            }
        }
    }
}

private struct CellView: View {
    let title: String
    let subtitle: String
    var isFavorite: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {}
                label: {
                    Label(isFavorite ? "Remove Favorite" : "Add Favorite", systemImage: "star")
                }
        }
    }
}

#Preview {
    NavigationStack {
        PlanningTopicsView()
    }
    .fontDesign(.rounded)
}
