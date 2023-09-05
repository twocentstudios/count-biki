import SwiftUI

struct TopicsView: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    CountBikiView()
                        .frame(height: 60)
                    Text("Let's practice counting!\nChoose a topic")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background {
                            Capsule()
                                .overlay(alignment: .topLeading) {
                                    Circle().frame(width: 10).offset(x: 1, y: -1)
                                    Circle().frame(width: 7).offset(x: -10, y: -8)
                                    Circle().frame(width: 4).offset(x: -18, y: -4)
                                }
                                .foregroundStyle(Color(.systemBackground))
                        }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowSeparator(.hidden)
                .listRowBackground(EmptyView())
            }
            .padding(.vertical, -10)
            
            Section("Favorites") {
                Text("Tap and hold to add a favorite")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }

            Section("Recently practiced") {
                Text("Topics you've studied will appear here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }

            Section {
                CellView(title: "Absolute Beginner", subtitle: "Whole numbers 0-10")
                CellView(title: "Beginner", subtitle: "Whole numbers 0-100")
                CellView(title: "Intermediate", subtitle: "Whole numbers 0-1,000")
                CellView(title: "Advanced", subtitle: "Whole numbers 0-10,000")
                CellView(title: "Extreme", subtitle: "Whole numbers 0-1,000,000,000")
            } header: {
                Text("Numbers \(Image(systemName: "number.circle"))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }

            Section {
                CellView(title: "Conbini", subtitle: "Yen amounts 100-1500")
                CellView(title: "Restaurant", subtitle: "Yen amounts 800-6000 by 10s")
                CellView(title: "Monthly Rent", subtitle: "Yen amounts 50,000-200,000 by 1,000s")
                CellView(title: "Annual Salary", subtitle: "Yen amounts 2,000,000-15,000,000 by 100,000s")
            } header: {
                Text("Money \(Image(systemName: "yensign.circle"))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
            
            Section {
                CellView(title: "Hours", subtitle: "1-48時間 (including 半)")
                CellView(title: "Minutes", subtitle: "1-100分間")
                CellView(title: "Seconds", subtitle: "1-100秒間")
                CellView(title: "Hours/Minutes", subtitle: "e.g. 24時間60分")
                CellView(title: "Hours/Minutes/Seconds", subtitle: "e.g. 24時間60分60秒")
                CellView(title: "Days", subtitle: "1-100日(間)")
                CellView(title: "Weeks", subtitle: "1-50週間")
                CellView(title: "Months", subtitle: "1-12か月 (including 半)")
                CellView(title: "Years", subtitle: "1-100年間 (including 半)")
            } header: {
                Text("Time Durations \(Image(systemName: "clock.circle"))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
            
            Section {
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
            } header: {
                Text("Dates & Times \(Image(systemName: "calendar.circle"))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.automatic)
    }
}

struct CellView: View {
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
            Button {
                // TODO:
            }
            label: {
                Label(isFavorite ? "Remove Favorite" : "Add Favorite", systemImage: "star")
            }
        }
    }
}

#Preview {
    TopicsView()
        .fontDesign(.rounded)
}
