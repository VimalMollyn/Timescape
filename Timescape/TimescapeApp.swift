//
//  TimescapeApp.swift
//  Timescape
//
//  Created by Vimal Mollyn on 12/8/24.
//

import SwiftUI

@main
struct TimescapeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
