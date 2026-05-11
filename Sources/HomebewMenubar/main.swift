import Cocoa

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
    private var cheersSoundItem: NSMenuItem!
    private var checkTimer: Timer?
    private var cheersTimer: Timer?
    private var isUpdating = false
    private var activeOperation: BrewUpdateOperation?
    private var latestProgress = UpdateProgress(percent: 0, message: "Starting update...")
    private var lastOutdatedPackages: [BrewPackage] = []
    private var packageByMenuTag: [Int: BrewPackage] = [:]
    private var nextPackageMenuTag = 1_000
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "playsCheersSound": true,
            "automaticallyUpdatesPackages": true
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
        cheersSoundItem = NSMenuItem(title: "Play Cheers Sound", action: #selector(toggleCheersSound), keyEquivalent: "")
        cheersSoundItem.target = self
        cheersSoundItem.image = MenuIcon.sound
        cheersSoundItem.state = playsCheersSound ? .on : .off

        let menu = NSMenu()
        menu.addItem(packageItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(refreshItem)
        menu.addItem(specificUpdateItem)
        menu.addItem(stopItem)
        menu.addItem(terminalItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(autoUpdateItem)
        menu.addItem(cheersSoundItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        render(.checking)
        checkForOutdatedPackages()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.checkForOutdatedPackages()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        checkTimer?.invalidate()
        cheersTimer?.invalidate()
        activeOperation?.cancel()
    }

    @objc private func refreshAndUpgrade() {
        guard !isUpdating else { return }
        beginUpdate(packages: lastOutdatedPackages, showsPackageNames: false)
    }

    @objc private func updateSpecificPackage(_ sender: NSMenuItem) {
        guard !isUpdating else { return }
        guard let package = packageByMenuTag[sender.tag] else { return }
        beginUpdate(packages: [package], showsPackageNames: true)
    }

    private func beginUpdate(packages: [BrewPackage], showsPackageNames: Bool) {
        isUpdating = true
        latestProgress = UpdateProgress(percent: 0, message: "Starting update...")
        render(.updating(latestProgress))

        activeOperation = checker.updatePackages(packages: packages, showsPackageNames: showsPackageNames) { [weak self] progress in
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
                case .success:
                    self.celebrateAfterNextCurrentCheck = true
                    self.checkForOutdatedPackages()
                case .failure(let error):
                    if (error as? BrewError) == .canceled {
                        self.render(.canceled)
                    } else if case let BrewError.passwordRequired(command) = error {
                        self.render(.passwordRequired(command))
                    } else {
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

    private func checkForOutdatedPackages() {
        guard !isUpdating else { return }

        render(.checking)
        checker.outdatedPackages { [weak self] result in
            DispatchQueue.main.async {
                guard let self, !self.isUpdating else { return }

                switch result {
                case .success(let packages):
                    self.lastOutdatedPackages = packages
                    if packages.isEmpty {
                        self.render(.current)
                        if self.celebrateAfterNextCurrentCheck {
                            self.celebrateAfterNextCurrentCheck = false
                            self.startCheersAnimation()
                        }
                    } else {
                        self.celebrateAfterNextCurrentCheck = false
                        if self.automaticallyUpdatesPackages {
                            self.beginUpdate(packages: packages, showsPackageNames: false)
                        } else {
                            self.render(.outdated(packages))
                        }
                    }
                case .failure(let error):
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
            packageItem.title = packageSummary(packages)
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
            specificUpdateItem.isHidden = lastOutdatedPackages.isEmpty
            specificUpdateItem.isEnabled = !lastOutdatedPackages.isEmpty
            specificUpdateItem.submenu = packageSubmenu(for: lastOutdatedPackages)
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
            specificUpdateItem.isHidden = lastOutdatedPackages.isEmpty
            specificUpdateItem.isEnabled = !lastOutdatedPackages.isEmpty
            specificUpdateItem.submenu = packageSubmenu(for: lastOutdatedPackages)
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

        return menu
    }
}

private struct UpdateProgress {
    let percent: Int
    let message: String
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
        onProgress: @escaping (UpdateProgress) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> BrewUpdateOperation {
        let operation = BrewUpdateOperation(
            packages: packages,
            showsPackageNames: showsPackageNames,
            runner: self,
            onProgress: onProgress,
            completion: completion
        )

        queue.async {
            operation.run()
        }

        return operation
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
    private let runner: BrewPackageService
    private let onProgress: (UpdateProgress) -> Void
    private let completion: (Result<Void, Error>) -> Void
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
        runner: BrewPackageService,
        onProgress: @escaping (UpdateProgress) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        self.packages = packages
        self.showsPackageNames = showsPackageNames
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
                return
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

            report(percent: 100, message: "Update complete")
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
    static let sound = symbol("speaker.wave.2")

    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }
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
