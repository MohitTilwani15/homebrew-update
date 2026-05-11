import Cocoa
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum State {
        case checking
        case current
        case outdated([BrewPackage])
        case updating(UpdateProgress)
        case failed(String)
        case passwordRequired(String)
        case canceled
        case brewMissing
    }

    private let checker = BrewPackageService()
    private var statusItem: NSStatusItem!
    private var packageItem: NSMenuItem!
    private var refreshItem: NSMenuItem!
    private var specificUpdateItem: NSMenuItem!
    private var stopItem: NSMenuItem!
    private var terminalItem: NSMenuItem!
    private var autoUpdateItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var updateFrequencyItem: NSMenuItem!
    private var quietHoursItem: NSMenuItem!
    private var cleanupItem: NSMenuItem!
    private var notificationsItem: NSMenuItem!
    private var cheersSoundItem: NSMenuItem!
    private var ignoredPackagesItem: NSMenuItem!
    private var doctorItem: NSMenuItem!
    private var lastCheckedItem: NSMenuItem!
    private var lastUpdatedItem: NSMenuItem!
    private var historyItem: NSMenuItem!
    private var checkTimer: Timer?
    private var brewDoctorTimer: Timer?
    private var cheersTimer: Timer?
    private var isUpdating = false
    private var activeOperation: BrewUpdateOperation?
    private var latestProgress = UpdateProgress(percent: 0, message: "Starting update...")
    private var lastOutdatedPackages: [BrewPackage] = []
    private var visibleOutdatedPackages: [BrewPackage] = []
    private var packageByMenuTag: [Int: BrewPackage] = [:]
    private var ignorePackageByMenuTag: [Int: BrewPackage] = [:]
    private var unignorePackageByMenuTag: [Int: String] = [:]
    private var frequencyByMenuTag: [Int: UpdateFrequency] = [:]
    private var nextPackageMenuTag = 1_000
    private var activeUpdateStartedAutomatically = false
    private var terminalCommand: String?
    private var celebrateAfterNextCurrentCheck = false
    private var playsCheersSound: Bool {
        get { UserDefaults.standard.bool(forKey: "playsCheersSound") }
        set { UserDefaults.standard.set(newValue, forKey: "playsCheersSound") }
    }
    private var automaticallyUpdatesPackages: Bool {
        get { UserDefaults.standard.bool(forKey: "automaticallyUpdatesPackages") }
        set { UserDefaults.standard.set(newValue, forKey: "automaticallyUpdatesPackages") }
    }
    private var updateFrequency: UpdateFrequency {
        get { UpdateFrequency(rawValue: UserDefaults.standard.string(forKey: "updateFrequency") ?? "") ?? .hourly }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "updateFrequency") }
    }
    private var quietHoursEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "quietHoursEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "quietHoursEnabled") }
    }
    private var runsCleanupAfterUpdates: Bool {
        get { UserDefaults.standard.bool(forKey: "runsCleanupAfterUpdates") }
        set { UserDefaults.standard.set(newValue, forKey: "runsCleanupAfterUpdates") }
    }
    private var sendsNotifications: Bool {
        get { UserDefaults.standard.bool(forKey: "sendsNotifications") }
        set { UserDefaults.standard.set(newValue, forKey: "sendsNotifications") }
    }
    private var ignoredPackageNames: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "ignoredPackageNames") ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: "ignoredPackageNames") }
    }
    private var updateHistory: [String] {
        get { UserDefaults.standard.stringArray(forKey: "updateHistory") ?? [] }
        set { UserDefaults.standard.set(Array(newValue.prefix(10)), forKey: "updateHistory") }
    }
    private var lastCheckedAt: Date? {
        get { UserDefaults.standard.object(forKey: "lastCheckedAt") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastCheckedAt") }
    }
    private var lastUpdatedAt: Date? {
        get { UserDefaults.standard.object(forKey: "lastUpdatedAt") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastUpdatedAt") }
    }
    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
    private var isInQuietHours: Bool {
        guard quietHoursEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 22 || hour < 8
    }
    private var shouldAutoUpdateNow: Bool {
        automaticallyUpdatesPackages && updateFrequency != .manual && !isInQuietHours
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "playsCheersSound": true,
            "automaticallyUpdatesPackages": true,
            "updateFrequency": UpdateFrequency.hourly.rawValue,
            "quietHoursEnabled": true,
            "runsCleanupAfterUpdates": false,
            "sendsNotifications": true
        ])
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "Homebew Menubar"

        packageItem = NSMenuItem(title: "Checking Homebrew...", action: nil, keyEquivalent: "")
        refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshAndUpgrade), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.image = MenuIcon.refresh
        specificUpdateItem = NSMenuItem(title: "Update One Package", action: nil, keyEquivalent: "")
        specificUpdateItem.image = MenuIcon.packageList
        specificUpdateItem.isHidden = true
        specificUpdateItem.isEnabled = false
        stopItem = NSMenuItem(title: "Stop Update", action: #selector(stopUpdate), keyEquivalent: ".")
        stopItem.target = self
        stopItem.image = MenuIcon.stop
        stopItem.isHidden = true
        stopItem.isEnabled = false
        terminalItem = NSMenuItem(title: "Open Terminal to Finish", action: #selector(openTerminalToFinish), keyEquivalent: "t")
        terminalItem.target = self
        terminalItem.image = MenuIcon.terminal
        terminalItem.isHidden = true
        terminalItem.isEnabled = false
        autoUpdateItem = NSMenuItem(title: "Auto Update in Background", action: #selector(toggleAutomaticUpdates), keyEquivalent: "")
        autoUpdateItem.target = self
        autoUpdateItem.image = MenuIcon.automaticUpdate
        autoUpdateItem.state = automaticallyUpdatesPackages ? .on : .off
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.image = MenuIcon.login
        launchAtLoginItem.state = launchAtLoginEnabled ? .on : .off
        updateFrequencyItem = NSMenuItem(title: "Check Frequency", action: nil, keyEquivalent: "")
        updateFrequencyItem.image = MenuIcon.frequency
        updateFrequencyItem.submenu = updateFrequencySubmenu()
        quietHoursItem = NSMenuItem(title: "Quiet Hours (10 PM-8 AM)", action: #selector(toggleQuietHours), keyEquivalent: "")
        quietHoursItem.target = self
        quietHoursItem.image = MenuIcon.quietHours
        quietHoursItem.state = quietHoursEnabled ? .on : .off
        cleanupItem = NSMenuItem(title: "Run Cleanup After Updates", action: #selector(toggleCleanupAfterUpdates), keyEquivalent: "")
        cleanupItem.target = self
        cleanupItem.image = MenuIcon.cleanup
        cleanupItem.state = runsCleanupAfterUpdates ? .on : .off
        notificationsItem = NSMenuItem(title: "Notify on Completion", action: #selector(toggleNotifications), keyEquivalent: "")
        notificationsItem.target = self
        notificationsItem.image = MenuIcon.notification
        notificationsItem.state = sendsNotifications ? .on : .off
        cheersSoundItem = NSMenuItem(title: "Play Cheers Sound", action: #selector(toggleCheersSound), keyEquivalent: "")
        cheersSoundItem.target = self
        cheersSoundItem.image = MenuIcon.sound
        cheersSoundItem.state = playsCheersSound ? .on : .off
        ignoredPackagesItem = NSMenuItem(title: "Ignored Packages", action: nil, keyEquivalent: "")
        ignoredPackagesItem.image = MenuIcon.ignored
        ignoredPackagesItem.submenu = ignoredPackagesSubmenu()
        doctorItem = NSMenuItem(title: "Brew Doctor: OK", action: #selector(openBrewDoctorInTerminal), keyEquivalent: "d")
        doctorItem.target = self
        doctorItem.image = MenuIcon.doctor
        doctorItem.isHidden = true
        lastCheckedItem = NSMenuItem(title: lastCheckedTitle, action: nil, keyEquivalent: "")
        lastCheckedItem.image = MenuIcon.checked
        lastUpdatedItem = NSMenuItem(title: lastUpdatedTitle, action: nil, keyEquivalent: "")
        lastUpdatedItem.image = MenuIcon.updated
        historyItem = NSMenuItem(title: "Update History", action: nil, keyEquivalent: "")
        historyItem.image = MenuIcon.history
        historyItem.submenu = historySubmenu()

        let menu = NSMenu()
        menu.addItem(packageItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(refreshItem)
        menu.addItem(specificUpdateItem)
        menu.addItem(stopItem)
        menu.addItem(terminalItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(lastCheckedItem)
        menu.addItem(lastUpdatedItem)
        menu.addItem(historyItem)
        menu.addItem(doctorItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(autoUpdateItem)
        menu.addItem(launchAtLoginItem)
        menu.addItem(updateFrequencyItem)
        menu.addItem(quietHoursItem)
        menu.addItem(cleanupItem)
        menu.addItem(notificationsItem)
        menu.addItem(cheersSoundItem)
        menu.addItem(ignoredPackagesItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        render(.checking)
        checkForOutdatedPackages()
        scheduleCheckTimer()
        scheduleBrewDoctorTimer()
        requestNotificationPermissionIfNeeded()
        checkBrewDoctor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        checkTimer?.invalidate()
        brewDoctorTimer?.invalidate()
        cheersTimer?.invalidate()
        activeOperation?.cancel()
    }

    @objc private func refreshAndUpgrade() {
        guard !isUpdating else { return }
        let packages = visibleOutdatedPackages.isEmpty ? actionablePackages(from: lastOutdatedPackages) : visibleOutdatedPackages
        beginUpdate(packages: packages, showsPackageNames: false)
    }

    @objc private func updateSpecificPackage(_ sender: NSMenuItem) {
        guard !isUpdating else { return }
        guard let package = packageByMenuTag[sender.tag] else { return }
        beginUpdate(packages: [package], showsPackageNames: true)
    }

    private func beginUpdate(packages: [BrewPackage], showsPackageNames: Bool, startedAutomatically: Bool = false) {
        isUpdating = true
        activeUpdateStartedAutomatically = startedAutomatically
        latestProgress = UpdateProgress(percent: 0, message: "Starting update...")
        render(.updating(latestProgress))

        activeOperation = checker.updatePackages(
            packages: packages,
            showsPackageNames: showsPackageNames,
            performsCleanup: runsCleanupAfterUpdates
        ) { [weak self] progress in
            DispatchQueue.main.async {
                guard let self, self.isUpdating else { return }
                self.latestProgress = progress
                self.render(.updating(progress))
            }
        } completion: { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isUpdating = false
                self.activeOperation = nil

                switch result {
                case .success(let updatedCount):
                    self.recordSuccessfulUpdate(packageCount: updatedCount)
                    self.celebrateAfterNextCurrentCheck = true
                    self.checkForOutdatedPackages()
                case .failure(let error):
                    if (error as? BrewError) == .canceled {
                        self.render(.canceled)
                    } else if case let BrewError.passwordRequired(command) = error {
                        self.notify(title: "Homebew needs Terminal", body: "A package needs your password to finish updating.")
                        self.render(.passwordRequired(command))
                    } else {
                        self.notify(title: "Homebew update failed", body: error.localizedDescription)
                        self.render(.failed(error.localizedDescription))
                        self.checkForOutdatedPackages()
                    }
                }
            }
        }
    }

    @objc private func stopUpdate() {
        guard isUpdating else { return }
        packageItem.title = "Stopping update..."
        stopItem.isEnabled = false
        activeOperation?.cancel()
    }

    @objc private func openTerminalToFinish() {
        guard let terminalCommand else { return }
        TerminalLauncher.open(command: terminalCommand)
    }

    @objc private func toggleCheersSound() {
        playsCheersSound.toggle()
        cheersSoundItem.state = playsCheersSound ? .on : .off
    }

    @objc private func toggleAutomaticUpdates() {
        automaticallyUpdatesPackages.toggle()
        autoUpdateItem.state = automaticallyUpdatesPackages ? .on : .off

        if automaticallyUpdatesPackages, !isUpdating {
            checkForOutdatedPackages()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if launchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            render(.failed("Could not update Launch at Login: \(error.localizedDescription)"))
        }
        launchAtLoginItem.state = launchAtLoginEnabled ? .on : .off
    }

    @objc private func selectUpdateFrequency(_ sender: NSMenuItem) {
        guard let frequency = frequencyByMenuTag[sender.tag] else { return }
        updateFrequency = frequency
        updateFrequencyItem.submenu = updateFrequencySubmenu()
        scheduleCheckTimer()
    }

    @objc private func toggleQuietHours() {
        quietHoursEnabled.toggle()
        quietHoursItem.state = quietHoursEnabled ? .on : .off
    }

    @objc private func toggleCleanupAfterUpdates() {
        runsCleanupAfterUpdates.toggle()
        cleanupItem.state = runsCleanupAfterUpdates ? .on : .off
    }

    @objc private func toggleNotifications() {
        sendsNotifications.toggle()
        notificationsItem.state = sendsNotifications ? .on : .off
        requestNotificationPermissionIfNeeded()
    }

    @objc private func ignorePackage(_ sender: NSMenuItem) {
        guard let package = ignorePackageByMenuTag[sender.tag] else { return }
        var ignored = ignoredPackageNames
        ignored.insert(package.name)
        ignoredPackageNames = ignored
        visibleOutdatedPackages = actionablePackages(from: lastOutdatedPackages)
        ignoredPackagesItem.submenu = ignoredPackagesSubmenu()
        render(visibleOutdatedPackages.isEmpty ? .current : .outdated(visibleOutdatedPackages))
    }

    @objc private func unignorePackage(_ sender: NSMenuItem) {
        guard let packageName = unignorePackageByMenuTag[sender.tag] else { return }
        var ignored = ignoredPackageNames
        ignored.remove(packageName)
        ignoredPackageNames = ignored
        visibleOutdatedPackages = actionablePackages(from: lastOutdatedPackages)
        ignoredPackagesItem.submenu = ignoredPackagesSubmenu()
        render(visibleOutdatedPackages.isEmpty ? .current : .outdated(visibleOutdatedPackages))
    }

    @objc private func openBrewDoctorInTerminal() {
        TerminalLauncher.open(command: "brew doctor")
    }

    private func checkForOutdatedPackages() {
        guard !isUpdating else { return }

        render(.checking)
        checker.outdatedPackages { [weak self] result in
            DispatchQueue.main.async {
                guard let self, !self.isUpdating else { return }

                switch result {
                case .success(let packages):
                    self.lastCheckedAt = Date()
                    self.updateStatusMenuItems()
                    self.lastOutdatedPackages = packages
                    self.visibleOutdatedPackages = self.actionablePackages(from: packages)
                    if self.visibleOutdatedPackages.isEmpty {
                        self.render(.current)
                        if !packages.isEmpty {
                            self.packageItem.title = "Only ignored packages are outdated"
                        }
                        if self.celebrateAfterNextCurrentCheck {
                            self.celebrateAfterNextCurrentCheck = false
                            self.startCheersAnimation()
                        }
                    } else {
                        self.celebrateAfterNextCurrentCheck = false
                        if self.shouldAutoUpdateNow {
                            self.beginUpdate(packages: self.visibleOutdatedPackages, showsPackageNames: false, startedAutomatically: true)
                        } else {
                            self.render(.outdated(self.visibleOutdatedPackages))
                        }
                    }
                case .failure(let error):
                    self.lastCheckedAt = Date()
                    self.updateStatusMenuItems()
                    self.celebrateAfterNextCurrentCheck = false
                    if (error as? BrewError) == .missingExecutable {
                        self.render(.brewMissing)
                    } else {
                        self.render(.failed(error.localizedDescription))
                    }
                }
            }
        }
    }

    private func actionablePackages(from packages: [BrewPackage]) -> [BrewPackage] {
        let ignored = ignoredPackageNames
        return packages.filter { !ignored.contains($0.name) }
    }

    private func scheduleCheckTimer() {
        checkTimer?.invalidate()
        guard let interval = updateFrequency.interval else { return }
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForOutdatedPackages()
        }
    }

    private func scheduleBrewDoctorTimer() {
        brewDoctorTimer?.invalidate()
        brewDoctorTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.checkBrewDoctor()
        }
    }

    private func checkBrewDoctor() {
        checker.brewDoctorStatus { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let warning):
                    self.doctorItem.isHidden = !warning
                    self.doctorItem.title = warning ? "Brew Doctor Needs Attention" : "Brew Doctor: OK"
                case .failure:
                    self.doctorItem.isHidden = false
                    self.doctorItem.title = "Brew Doctor Check Failed"
                }
            }
        }
    }

    private func recordSuccessfulUpdate(packageCount: Int) {
        lastUpdatedAt = Date()
        updateStatusMenuItems()

        let packageText = packageCount == 1 ? "1 package" : "\(packageCount) packages"
        let modeText = activeUpdateStartedAutomatically ? "Auto-updated" : "Updated"
        let historyEntry = "\(DateFormatter.history.string(from: Date())) - \(modeText) \(packageText)"
        updateHistory = [historyEntry] + updateHistory
        historyItem.submenu = historySubmenu()

        notify(title: "Homebew update complete", body: "\(modeText) \(packageText).")
    }

    private func updateStatusMenuItems() {
        lastCheckedItem.title = lastCheckedTitle
        lastUpdatedItem.title = lastUpdatedTitle
    }

    private var lastCheckedTitle: String {
        guard let lastCheckedAt else { return "Last checked: Never" }
        return "Last checked: \(DateFormatter.menuTime.string(from: lastCheckedAt))"
    }

    private var lastUpdatedTitle: String {
        guard let lastUpdatedAt else { return "Last updated: Never" }
        return "Last updated: \(DateFormatter.menuTime.string(from: lastUpdatedAt))"
    }

    private func requestNotificationPermissionIfNeeded() {
        guard sendsNotifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        guard sendsNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func startCheersAnimation() {
        cheersTimer?.invalidate()
        if playsCheersSound {
            NSSound(named: NSSound.Name("Glass"))?.play()
        }

        let frames: [CGFloat] = [0.18, 0.38, 0.62, 0.84, 1.0, 0.88, 0.96, 0.9]
        var frameIndex = 0
        packageItem.title = "All caught up. Cheers!"

        cheersTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            guard frameIndex < frames.count else {
                timer.invalidate()
                self.cheersTimer = nil
                self.render(.current)
                return
            }

            self.statusItem.button?.image = BeerIcon.image(fillLevel: frames[frameIndex])
            frameIndex += 1
        }
    }

    private func render(_ state: State) {
        switch state {
        case .checking:
            statusItem.button?.image = BeerIcon.image(fillLevel: 0.55)
            statusItem.button?.toolTip = "Checking Homebrew packages"
            packageItem.title = "Checking Homebrew..."
            refreshItem.isEnabled = false
            refreshItem.title = "Refresh"
            refreshItem.image = MenuIcon.refresh
            specificUpdateItem.isHidden = true
            specificUpdateItem.isEnabled = false
            stopItem.isHidden = true
            stopItem.isEnabled = false
            terminalItem.isHidden = true
            terminalItem.isEnabled = false
        case .current:
            statusItem.button?.image = BeerIcon.image(fillLevel: 0.9)
            statusItem.button?.toolTip = "Homebrew packages are up to date"
            packageItem.title = "All packages are up to date"
            refreshItem.isEnabled = true
            refreshItem.title = "Refresh"
            refreshItem.image = MenuIcon.refresh
            specificUpdateItem.isHidden = true
            specificUpdateItem.isEnabled = false
            stopItem.isHidden = true
            stopItem.isEnabled = false
            terminalItem.isHidden = true
            terminalItem.isEnabled = false
        case .outdated(let packages):
            statusItem.button?.image = BeerIcon.image(fillLevel: 0.08)
            statusItem.button?.toolTip = "\(packages.count) Homebrew package\(packages.count == 1 ? "" : "s") need updating"
            packageItem.title = automaticallyUpdatesPackages && isInQuietHours ? "Quiet hours. \(packageSummary(packages))" : packageSummary(packages)
            refreshItem.isEnabled = true
            refreshItem.title = packages.count == 1 ? "Update Package" : "Update All Packages"
            refreshItem.image = MenuIcon.refresh
            specificUpdateItem.isHidden = packages.isEmpty
            specificUpdateItem.isEnabled = !packages.isEmpty
            specificUpdateItem.submenu = packageSubmenu(for: packages)
            stopItem.isHidden = true
            stopItem.isEnabled = false
            terminalItem.isHidden = true
            terminalItem.isEnabled = false
        case .updating(let progress):
            statusItem.button?.image = BeerIcon.image(fillLevel: CGFloat(progress.percent) / 100.0)
            statusItem.button?.toolTip = "Updating Homebrew packages: \(progress.percent)%"
            packageItem.title = "\(progress.percent)% - \(progress.message)"
            refreshItem.isEnabled = false
            refreshItem.title = "Updating \(progress.percent)%"
            refreshItem.image = MenuIcon.updating
            specificUpdateItem.isHidden = true
            specificUpdateItem.isEnabled = false
            stopItem.isHidden = false
            stopItem.isEnabled = true
            terminalItem.isHidden = true
            terminalItem.isEnabled = false
        case .failed(let message):
            statusItem.button?.image = BeerIcon.image(fillLevel: 0.08)
            statusItem.button?.toolTip = "Homebrew update failed"
            packageItem.title = "Error: \(message)"
            refreshItem.isEnabled = true
            refreshItem.title = "Try Again"
            refreshItem.image = MenuIcon.refresh
            specificUpdateItem.isHidden = true
            specificUpdateItem.isEnabled = false
            stopItem.isHidden = true
            stopItem.isEnabled = false
            terminalItem.isHidden = true
            terminalItem.isEnabled = false
        case .passwordRequired(let command):
            terminalCommand = command
            statusItem.button?.image = BeerIcon.image(fillLevel: 0.08)
            statusItem.button?.toolTip = "Homebrew needs your password in Terminal"
            packageItem.title = "Password required in Terminal"
            refreshItem.isEnabled = true
            refreshItem.title = "Refresh"
            refreshItem.image = MenuIcon.refresh
            specificUpdateItem.isHidden = visibleOutdatedPackages.isEmpty
            specificUpdateItem.isEnabled = !visibleOutdatedPackages.isEmpty
            specificUpdateItem.submenu = packageSubmenu(for: visibleOutdatedPackages)
            stopItem.isHidden = true
            stopItem.isEnabled = false
            terminalItem.isHidden = false
            terminalItem.isEnabled = true
        case .canceled:
            statusItem.button?.image = BeerIcon.image(fillLevel: 0.08)
            statusItem.button?.toolTip = "Homebrew update was stopped"
            packageItem.title = "Update stopped"
            refreshItem.isEnabled = true
            refreshItem.title = "Try Again"
            refreshItem.image = MenuIcon.refresh
            specificUpdateItem.isHidden = visibleOutdatedPackages.isEmpty
            specificUpdateItem.isEnabled = !visibleOutdatedPackages.isEmpty
            specificUpdateItem.submenu = packageSubmenu(for: visibleOutdatedPackages)
            stopItem.isHidden = true
            stopItem.isEnabled = false
            terminalItem.isHidden = true
            terminalItem.isEnabled = false
        case .brewMissing:
            statusItem.button?.image = BeerIcon.image(fillLevel: 0.08)
            statusItem.button?.toolTip = "Homebrew was not found"
            packageItem.title = "Homebrew was not found"
            refreshItem.isEnabled = false
            refreshItem.title = "Refresh"
            refreshItem.image = MenuIcon.refresh
            specificUpdateItem.isHidden = true
            specificUpdateItem.isEnabled = false
            stopItem.isHidden = true
            stopItem.isEnabled = false
            terminalItem.isHidden = true
            terminalItem.isEnabled = false
        }
    }

    private func packageSummary(_ packages: [BrewPackage]) -> String {
        if packages.count == 1 {
            return "1 package needs updating"
        }

        return "\(packages.count) packages need updating"
    }

    private func packageSubmenu(for packages: [BrewPackage]) -> NSMenu {
        let menu = NSMenu()
        packageByMenuTag.removeAll()
        ignorePackageByMenuTag.removeAll()
        nextPackageMenuTag = 1_000

        let header = NSMenuItem(title: "Choose a package to update", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        for package in packages {
            let item = NSMenuItem(title: package.menuTitle, action: #selector(updateSpecificPackage(_:)), keyEquivalent: "")
            item.target = self
            item.image = package.kind == .cask ? MenuIcon.cask : MenuIcon.formula
            item.toolTip = package.detailText
            item.tag = nextPackageMenuTag
            packageByMenuTag[item.tag] = package
            nextPackageMenuTag += 1
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        let ignoreHeader = NSMenuItem(title: "Ignore from auto-update", action: nil, keyEquivalent: "")
        ignoreHeader.isEnabled = false
        menu.addItem(ignoreHeader)
        for package in packages {
            let item = NSMenuItem(title: package.name, action: #selector(ignorePackage(_:)), keyEquivalent: "")
            item.target = self
            item.image = MenuIcon.ignored
            item.tag = nextPackageMenuTag
            ignorePackageByMenuTag[item.tag] = package
            nextPackageMenuTag += 1
            menu.addItem(item)
        }

        return menu
    }

    private func ignoredPackagesSubmenu() -> NSMenu {
        let menu = NSMenu()
        unignorePackageByMenuTag.removeAll()
        let ignored = ignoredPackageNames.sorted()

        guard !ignored.isEmpty else {
            let item = NSMenuItem(title: "No ignored packages", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return menu
        }

        for packageName in ignored {
            let item = NSMenuItem(title: "Stop ignoring \(packageName)", action: #selector(unignorePackage(_:)), keyEquivalent: "")
            item.target = self
            item.image = MenuIcon.unignored
            item.tag = nextPackageMenuTag
            unignorePackageByMenuTag[item.tag] = packageName
            nextPackageMenuTag += 1
            menu.addItem(item)
        }

        return menu
    }

    private func updateFrequencySubmenu() -> NSMenu {
        let menu = NSMenu()
        frequencyByMenuTag.removeAll()

        for frequency in UpdateFrequency.allCases {
            let item = NSMenuItem(title: frequency.title, action: #selector(selectUpdateFrequency(_:)), keyEquivalent: "")
            item.target = self
            item.state = frequency == updateFrequency ? .on : .off
            item.tag = nextPackageMenuTag
            frequencyByMenuTag[item.tag] = frequency
            nextPackageMenuTag += 1
            menu.addItem(item)
        }

        return menu
    }

    private func historySubmenu() -> NSMenu {
        let menu = NSMenu()
        let history = updateHistory

        guard !history.isEmpty else {
            let item = NSMenuItem(title: "No updates yet", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return menu
        }

        for entry in history {
            let item = NSMenuItem(title: entry, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        return menu
    }
}

private struct UpdateProgress {
    let percent: Int
    let message: String
}

private enum UpdateFrequency: String, CaseIterable {
    case hourly
    case sixHours
    case daily
    case manual

    var title: String {
        switch self {
        case .hourly:
            return "Hourly"
        case .sixHours:
            return "Every 6 Hours"
        case .daily:
            return "Daily"
        case .manual:
            return "Manual Only"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .hourly:
            return 60 * 60
        case .sixHours:
            return 6 * 60 * 60
        case .daily:
            return 24 * 60 * 60
        case .manual:
            return nil
        }
    }
}

private struct BrewPackage {
    enum Kind {
        case formula
        case cask

        var label: String {
            switch self {
            case .formula:
                return "Formula"
            case .cask:
                return "Cask"
            }
        }
    }

    let kind: Kind
    let name: String
    let installedVersions: [String]
    let currentVersion: String?

    var upgradeArguments: [String] {
        switch kind {
        case .formula:
            return ["upgrade", "--formula", name]
        case .cask:
            return ["upgrade", "--cask", name]
        }
    }

    var menuTitle: String {
        "\(name)  \(versionSummary)"
    }

    var detailText: String {
        "\(kind.label) · \(versionSummary)"
    }

    private var versionSummary: String {
        guard let currentVersion, !currentVersion.isEmpty else {
            return kind.label
        }

        let installed = installedVersions.first ?? "installed"
        return "\(installed) -> \(currentVersion)"
    }
}

private struct BrewOutdatedSnapshot: Decodable {
    struct Formula: Decodable {
        let name: String
        let pinned: Bool?
        let installed_versions: [String]?
        let current_version: String?
    }

    struct Cask: Decodable {
        let name: String
        let installed_versions: [String]?
        let current_version: String?
    }

    let formulae: [Formula]
    let casks: [Cask]

    var upgradeablePackages: [BrewPackage] {
        let formulaPackages = formulae
            .filter { $0.pinned != true }
            .map {
                BrewPackage(
                    kind: .formula,
                    name: $0.name,
                    installedVersions: $0.installed_versions ?? [],
                    currentVersion: $0.current_version
                )
            }
        let caskPackages = casks.map {
            BrewPackage(
                kind: .cask,
                name: $0.name,
                installedVersions: $0.installed_versions ?? [],
                currentVersion: $0.current_version
            )
        }

        return formulaPackages + caskPackages
    }
}

private enum BrewError: LocalizedError, Equatable {
    case missingExecutable
    case canceled
    case invalidOutdatedJSON
    case passwordRequired(String)
    case failed(command: String, output: String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable:
            return "Could not find the brew executable."
        case .canceled:
            return "Update stopped."
        case .invalidOutdatedJSON:
            return "Could not read Homebrew outdated package data."
        case .passwordRequired:
            return "Homebrew needs your password in Terminal."
        case .failed(let command, let output):
            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedOutput.isEmpty {
                return "`brew \(command)` failed."
            }
            return "`brew \(command)` failed: \(trimmedOutput)"
        }
    }
}

private final class BrewPackageService {
    private let queue = DispatchQueue(label: "homebew-menubar.brew", qos: .utility)

    func outdatedPackages(completion: @escaping (Result<[BrewPackage], Error>) -> Void) {
        queue.async {
            completion(Result {
                try self.outdatedPackages(operation: nil)
            })
        }
    }

    func updatePackages(
        packages: [BrewPackage],
        showsPackageNames: Bool,
        performsCleanup: Bool,
        onProgress: @escaping (UpdateProgress) -> Void,
        completion: @escaping (Result<Int, Error>) -> Void
    ) -> BrewUpdateOperation {
        let operation = BrewUpdateOperation(
            packages: packages,
            showsPackageNames: showsPackageNames,
            performsCleanup: performsCleanup,
            runner: self,
            onProgress: onProgress,
            completion: completion
        )

        queue.async {
            operation.run()
        }

        return operation
    }

    func brewDoctorStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
        queue.async {
            do {
                _ = try self.runBrew(["doctor"])
                completion(.success(false))
            } catch BrewError.failed(_, let output) {
                completion(.success(!output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            } catch {
                completion(.failure(error))
            }
        }
    }

    fileprivate func runBrew(
        _ arguments: [String],
        operation: BrewUpdateOperation? = nil,
        onOutput: ((String) -> Void)? = nil
    ) throws -> String {
        guard let brewURL = brewExecutableURL() else {
            throw BrewError.missingExecutable
        }
        if operation?.isCanceled == true {
            throw BrewError.canceled
        }

        let process = Process()
        process.executableURL = brewURL
        process.arguments = arguments
        process.environment = environment()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let outputLock = NSLock()
        var stdout = ""
        var stderr = ""

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            outputLock.lock()
            stdout += chunk
            outputLock.unlock()
            onOutput?(chunk)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            outputLock.lock()
            stderr += chunk
            outputLock.unlock()
            onOutput?(chunk)
        }

        try process.run()
        operation?.setCurrentProcess(process)
        process.waitUntilExit()
        operation?.setCurrentProcess(nil)
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        let remainingStdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        if !remainingStdoutData.isEmpty, let remaining = String(data: remainingStdoutData, encoding: .utf8) {
            outputLock.lock()
            stdout += remaining
            outputLock.unlock()
            onOutput?(remaining)
        }
        let remainingStderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if !remainingStderrData.isEmpty, let remaining = String(data: remainingStderrData, encoding: .utf8) {
            outputLock.lock()
            stderr += remaining
            outputLock.unlock()
            onOutput?(remaining)
        }

        outputLock.lock()
        let fullStdout = stdout
        let fullOutput = stdout + stderr
        outputLock.unlock()

        if operation?.isCanceled == true {
            throw BrewError.canceled
        }
        guard process.terminationStatus == 0 else {
            if passwordPromptRequired(in: fullOutput) {
                throw BrewError.passwordRequired(terminalCommand(for: arguments))
            }
            throw BrewError.failed(command: arguments.joined(separator: " "), output: fullOutput)
        }

        return fullStdout
    }

    private func passwordPromptRequired(in output: String) -> Bool {
        let normalizedOutput = output.lowercased()
        return normalizedOutput.contains("sudo") &&
            (
                normalizedOutput.contains("password") ||
                normalizedOutput.contains("a terminal is required") ||
                normalizedOutput.contains("no tty present")
            )
    }

    private func terminalCommand(for arguments: [String]) -> String {
        let executable = brewExecutableURL()?.path ?? "brew"
        let command = ([executable] + arguments).map(shellQuoted).joined(separator: " ")
        return [
            "export HOMEBREW_NO_ENV_HINTS=1",
            command,
            "echo",
            "echo 'Return to Homebew Menubar and choose Refresh when Terminal finishes.'"
        ].joined(separator: "; ")
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    fileprivate func outdatedPackages(operation: BrewUpdateOperation?) throws -> [BrewPackage] {
        let output = try runBrew(["outdated", "--json=v2"], operation: operation)
        guard let data = jsonData(from: output),
              let snapshot = try? JSONDecoder().decode(BrewOutdatedSnapshot.self, from: data) else {
            throw BrewError.invalidOutdatedJSON
        }

        return snapshot.upgradeablePackages
    }

    private func jsonData(from output: String) -> Data? {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmedOutput.data(using: .utf8),
           (try? JSONDecoder().decode(BrewOutdatedSnapshot.self, from: data)) != nil {
            return data
        }

        guard let start = trimmedOutput.firstIndex(of: "{"),
              let end = trimmedOutput.lastIndex(of: "}"),
              start <= end else {
            return nil
        }

        return String(trimmedOutput[start...end]).data(using: .utf8)
    }

    private func brewExecutableURL() -> URL? {
        let paths = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "/home/linuxbrew/.linuxbrew/bin/brew"
        ]

        return paths
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let path = env["PATH"] ?? ""
        env["PATH"] = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            path
        ].joined(separator: ":")
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        return env
    }
}

private final class BrewUpdateOperation {
    private var packages: [BrewPackage]
    private let showsPackageNames: Bool
    private let performsCleanup: Bool
    private let runner: BrewPackageService
    private let onProgress: (UpdateProgress) -> Void
    private let completion: (Result<Int, Error>) -> Void
    private let lock = NSLock()
    private var currentProcess: Process?
    private var canceled = false
    private var completedPackages = 0

    var isCanceled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return canceled
    }

    init(
        packages: [BrewPackage],
        showsPackageNames: Bool,
        performsCleanup: Bool,
        runner: BrewPackageService,
        onProgress: @escaping (UpdateProgress) -> Void,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        self.packages = packages
        self.showsPackageNames = showsPackageNames
        self.performsCleanup = performsCleanup
        self.runner = runner
        self.onProgress = onProgress
        self.completion = completion
    }

    func run() {
        completion(Result {
            report(percent: 2, message: "Updating Homebrew metadata")
            _ = try runner.runBrew(["update"], operation: self) { [weak self] chunk in
                self?.handleUpdateOutput(chunk)
            }

            if packages.isEmpty {
                packages = try runner.outdatedPackages(operation: self)
            }

            guard !packages.isEmpty else {
                report(percent: 100, message: "No packages need updating")
                return 0
            }

            for (index, package) in packages.enumerated() {
                try throwIfCanceled()
                report(percent: percent(completed: index), message: updateCountMessage(completed: index))
                _ = try runner.runBrew(package.upgradeArguments, operation: self) { [weak self] _ in
                    guard let self else { return }
                    self.report(percent: self.percent(completed: index), message: self.updateCountMessage(completed: index))
                }

                lock.lock()
                completedPackages = index + 1
                lock.unlock()
                report(percent: percent(completed: index + 1), message: updateCountMessage(completed: index + 1))
            }

            if performsCleanup {
                report(percent: 96, message: "Cleaning up Homebrew")
                _ = try runner.runBrew(["cleanup"], operation: self)
            }

            report(percent: 100, message: "Update complete")
            return completedPackages
        })
    }

    func cancel() {
        lock.lock()
        canceled = true
        let process = currentProcess
        lock.unlock()

        process?.interrupt()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
            if process?.isRunning == true {
                process?.terminate()
            }
        }
    }

    fileprivate func setCurrentProcess(_ process: Process?) {
        lock.lock()
        currentProcess = process
        let shouldCancel = canceled
        lock.unlock()

        if shouldCancel {
            process?.interrupt()
        }
    }

    private func handleUpdateOutput(_ chunk: String) {
        if chunk.localizedCaseInsensitiveContains("Already up-to-date") {
            report(percent: 20, message: "Homebrew metadata is current")
        } else if chunk.localizedCaseInsensitiveContains("Updated") {
            report(percent: 20, message: "Homebrew metadata updated")
        } else {
            report(percent: 12, message: "Updating Homebrew metadata")
        }
    }

    private func packageProgressDenominator() -> Int {
        max(packages.count, completedPackages, 1)
    }

    private func updateCountMessage(completed: Int) -> String {
        if showsPackageNames, let package = packages.first {
            return completed > 0 ? "Updated \(package.name)" : "Updating \(package.name)"
        }

        let total = packageProgressDenominator()
        if total == 1 {
            return completed > 0 ? "Updated 1 package" : "Updating 1 package"
        }

        return "Updating package \(min(completed + 1, total)) of \(total)"
    }

    private func percent(completed: Int) -> Int {
        min(95, 25 + Int((Double(completed) / Double(packageProgressDenominator())) * 70.0))
    }

    private func throwIfCanceled() throws {
        if isCanceled {
            throw BrewError.canceled
        }
    }

    private func report(percent: Int, message: String) {
        guard !isCanceled else { return }
        onProgress(UpdateProgress(percent: max(0, min(100, percent)), message: message))
    }
}

private enum MenuIcon {
    static let refresh = symbol("arrow.clockwise")
    static let updating = symbol("arrow.triangle.2.circlepath")
    static let packageList = symbol("list.bullet")
    static let formula = symbol("terminal")
    static let cask = symbol("app")
    static let stop = symbol("stop.circle")
    static let terminal = symbol("terminal")
    static let automaticUpdate = symbol("clock.arrow.circlepath")
    static let login = symbol("power")
    static let frequency = symbol("timer")
    static let quietHours = symbol("moon")
    static let cleanup = symbol("trash")
    static let notification = symbol("bell")
    static let sound = symbol("speaker.wave.2")
    static let ignored = symbol("eye.slash")
    static let unignored = symbol("eye")
    static let doctor = symbol("stethoscope")
    static let checked = symbol("checkmark.circle")
    static let updated = symbol("checkmark.seal")
    static let history = symbol("clock")

    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }
}

private extension DateFormatter {
    static let menuTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static let history: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private enum TerminalLauncher {
    static func open(command: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "\(appleScriptEscaped(command))"
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private enum BeerIcon {
    static func image(fillLevel: CGFloat) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        let glassRect = NSRect(x: 5.3, y: 3.2, width: 11.5, height: 15.0)
        let glassPath = NSBezierPath(roundedRect: glassRect, xRadius: 2.2, yRadius: 2.2)
        glassPath.lineWidth = 1.4
        NSColor.labelColor.setStroke()
        glassPath.stroke()

        let handlePath = NSBezierPath()
        handlePath.lineWidth = 1.4
        handlePath.move(to: NSPoint(x: 16.5, y: 14.6))
        handlePath.curve(to: NSPoint(x: 16.5, y: 7.0), controlPoint1: NSPoint(x: 21.0, y: 14.4), controlPoint2: NSPoint(x: 21.0, y: 7.2))
        handlePath.curve(to: NSPoint(x: 16.5, y: 9.5), controlPoint1: NSPoint(x: 18.2, y: 7.3), controlPoint2: NSPoint(x: 18.2, y: 9.2))
        handlePath.stroke()

        let clampedLevel = max(0, min(1, fillLevel))
        if clampedLevel > 0 {
            let inset: CGFloat = 1.6
            let availableHeight = glassRect.height - (inset * 2)
            let beerHeight = availableHeight * clampedLevel
            let beerRect = NSRect(
                x: glassRect.minX + inset,
                y: glassRect.minY + inset,
                width: glassRect.width - (inset * 2),
                height: beerHeight
            )
            let beerPath = NSBezierPath(roundedRect: beerRect, xRadius: 1.1, yRadius: 1.1)
            NSColor.systemYellow.setFill()
            beerPath.fill()
        }

        if clampedLevel > 0.65 {
            NSColor.labelColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: 5.1, y: 16.5, width: 4.6, height: 3.2)).fill()
            NSBezierPath(ovalIn: NSRect(x: 8.2, y: 17.0, width: 5.5, height: 3.6)).fill()
            NSBezierPath(ovalIn: NSRect(x: 12.3, y: 16.4, width: 4.7, height: 3.2)).fill()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

@main
private enum Main {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
