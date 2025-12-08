import CrossmintAuth
import CrossmintClient
import SwiftUI

@main
struct CrossmintDemoApp: App {
    @State private var selectedOption = ViewOptions.exactIn

    private enum ViewOptions: String, CaseIterable, Identifiable {
        case exactIn = "CKO exact-in"
        case exactOut = "CKO exact-out"
        case completed = "Completed"

        var id: Self { self }
    }

    var body: some Scene {
        WindowGroup {
            VStack {
                // Navigation using segmented picker
                Picker("View", selection: $selectedOption) {
                    ForEach(ViewOptions.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content view based on selection
                switch selectedOption {
                case .exactIn:
                    EmbeddedCheckoutView(executionMode: .exactIn)
                case .exactOut:
                    EmbeddedCheckoutView(executionMode: .exactOut)
                case .completed:
                    EmbeddedCompletedView()
                }

                Spacer()
            }
        }
    }
}
