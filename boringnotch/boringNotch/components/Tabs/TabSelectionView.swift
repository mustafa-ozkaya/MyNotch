//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    let label: String
    let icon: String
    let view: NotchViews
    var id: NotchViews { view }

    /// The tabs shown in the notch header, in order. Home is always present;
    /// the others follow their Settings toggles.
    static func visibleTabs(showShelf: Bool, showLauncher: Bool, showClipboard: Bool) -> [TabModel] {
        var tabs = [TabModel(label: "Home", icon: "house.fill", view: .home)]
        if showShelf {
            tabs.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
        }
        if showLauncher {
            tabs.append(TabModel(label: "Launcher", icon: "square.grid.2x2.fill", view: .launcher))
        }
        if showClipboard {
            tabs.append(TabModel(label: "Clipboard", icon: "doc.on.clipboard.fill", view: .clipboard))
        }
        return tabs
    }

    /// Tabs visible with the current Defaults values.
    static var visibleTabs: [TabModel] {
        visibleTabs(
            showShelf: Defaults[.boringShelf],
            showLauncher: Defaults[.showLauncherTab],
            showClipboard: Defaults[.showClipboardTab]
        )
    }
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.boringShelf) var showShelf
    @Default(.showLauncherTab) var showLauncher
    @Default(.showClipboardTab) var showClipboard
    @Namespace var animation

    private var tabs: [TabModel] {
        TabModel.visibleTabs(showShelf: showShelf, showLauncher: showLauncher, showClipboard: showClipboard)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                    TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                        withAnimation(.smooth) {
                            coordinator.currentView = tab.view
                        }
                    }
                    .frame(height: 26)
                    .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                    .background {
                        if tab.view == coordinator.currentView {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
            }
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
