import PhathomCore
import SwiftUI
import UIKit

enum AppAppearance {
    private static var didConfigure = false

    static func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        let carbon = UIColor(red: 37 / 255, green: 36 / 255, blue: 34 / 255, alpha: 1)
        let charcoal = UIColor(red: 64 / 255, green: 61 / 255, blue: 57 / 255, alpha: 1)
        let floral = UIColor(red: 1, green: 0.988, blue: 0.949, alpha: 1)
        let dust = UIColor(red: 0.8, green: 0.773, blue: 0.725, alpha: 1)
        let paprika = UIColor(red: 235 / 255, green: 94 / 255, blue: 40 / 255, alpha: 1)

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = charcoal
        tab.shadowColor = .clear

        let itemNormal = UITabBarItemAppearance()
        itemNormal.normal.iconColor = dust
        itemNormal.normal.titleTextAttributes = [.foregroundColor: dust]
        itemNormal.selected.iconColor = paprika
        itemNormal.selected.titleTextAttributes = [.foregroundColor: paprika]

        tab.stackedLayoutAppearance = itemNormal
        tab.inlineLayoutAppearance = itemNormal
        tab.compactInlineLayoutAppearance = itemNormal

        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = carbon
        nav.titleTextAttributes = [.foregroundColor: floral]
        nav.largeTitleTextAttributes = [.foregroundColor: floral]

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().compactScrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = paprika

        UITableView.appearance().backgroundColor = carbon
        UITableViewCell.appearance().backgroundColor = charcoal

        let header = UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self])
        header.textColor = dust
    }
}
