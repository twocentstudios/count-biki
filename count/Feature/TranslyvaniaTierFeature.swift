import ComposableArchitecture
import SwiftUI

struct TransylvaniaTierFeature: Reducer {
    struct State: Equatable {
        let hasTranslyvaniaTier: Bool = false
        let canMakePayments: Bool = true // TODO: AppStore.canMakePayments
    }

    enum Action: Equatable {}

    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {}
        }
    }
}

struct TranslyvaniaTierView: View {
    let store: StoreOf<TransylvaniaTierFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        if viewStore.hasTranslyvaniaTier {
                            Text("You've unlocked...")
                                .font(.subheadline)
                            Text("Translyvania Tier")
                                .font(.largeTitle)
                                .fontWeight(.black)
                                .foregroundStyle(LinearGradient(colors: [Color.red, Color.orange, Color.yellow], startPoint: .bottomLeading, endPoint: .topTrailing))
                            Text("Thanks for supporting development")
                                .fontDesign(.default)
                                .italic()
                            Text("If you find Count Biki useful, you're welcome to leave another tip :)")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Leave any size tip to unlock...")
                                .font(.subheadline)
                            Text("Translyvania Tier")
                                .font(.largeTitle)
                                .fontWeight(.black)
                                .foregroundStyle(LinearGradient(colors: [Color.red, Color.orange, Color.yellow], startPoint: .bottomLeading, endPoint: .topTrailing))
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(Image(systemName: "1.circle"))  Choose your favorite app icon")
                                Text("\(Image(systemName: "2.circle"))  Support ongoing development")
                            }
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    VStack(spacing: 0) {
                        Button {} label: {
                            HStack(spacing: 0) {
                                Image(systemName: "circle")
                                    .padding(.trailing, 10)
                                Text("Atomic red carrot tip")
                                    .font(.title3)
                                    .fontWeight(.black)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 16)
                                Text("$0.99")
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 10)
                                    .background {
                                        RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: 2)
                                    }
                                    .background(Material.ultraThick)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(.vertical, 40)
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background { RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemFill)) }
                        }
                        .buttonStyle(.plain)
                        Button {} label: {
                            Text("Sunblock tip")
                        }
                        Button {} label: {
                            Text("Coffin tip")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Translyvania Tier")
        }
    }
}

#Preview {
    TranslyvaniaTierView(
        store: Store(initialState: TransylvaniaTierFeature.State()) {
            TransylvaniaTierFeature()
                ._printChanges()
        }
    )
    .fontDesign(.rounded)
}
