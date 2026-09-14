/*
 * [INPUT]: 依赖特性仓库、命令中心与独立 LanguagePreferences 展示状态
 * [OUTPUT]: 组装窗口、菜单、共享业务依赖与实时语言环境
 * [POS]: 应用组合根；语言变化仅更新环境，不重建业务服务或窗口身份
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  BrewApp.swift
//  Brew
//
//  Created by Graeme Arthur on 6/3/2026.
//

import AppKit
import BrewAppEnvironment
import BrewCLI
import BrewCore
import BrewCrashReporting
import BrewFeatureConsole
import BrewFeatureSelfUpgrade
import BrewNetworking
import BrewRepositories
import BrewRepositoryInterfaces
import BrewSelfUpgradeContract
import BrewUIComponents
import BrewUITestContract
import SwiftUI

@main
struct BrewApp: App {
    private static let documentationURL = URL(string: "https://docs.brew.sh/")!
    private static let reportIssueURL = URL(string: "https://github.com/Homebrew/BrewUI/issues/new")!

    @Environment(\.scenePhase) private var scenePhase

    @State private var languagePreferences: LanguagePreferences

    private let nativeMenuRefresh = NativeMenuRefresh()
    private let standardAppCommandState = StandardAppCommandState()
    private let standardEditingState = StandardEditingValidationState()
    private static let mainWindowID = "main"

    private let commandCenter: SerialBrewCommandCenter
    private let commandFactory: LiveBrewMutatingCommandFactory
    private let installedInventoryCache: InstalledInventoryCache
    private let catalogueCache: CatalogueCache
    private let discoverAnalyticsCache: DiscoverAnalyticsCache
    private let installedPackagesRepository: BrewInstalledPackagesRepository
    private let commandJobsRepository: BrewCommandJobsRepository
    private let installedDependentsRepository: BrewInstalledDependentsRepository
    private let catalogueRepository: BrewCatalogueRepository
    private let discoverPackagesRepository: BrewDiscoverPackagesRepository
    private let doctorRepository: BrewDoctorRepository
    private let configRepository: BrewConfigRepository
    private let crashReportController: CrashReportController
    private let selfUpgradeCoordinator: SelfUpgradeCoordinator
    #if DEBUG
        private let selfUpgradeDebugControl = SelfUpgradeDebugControl()
    #endif

    init() {
        // Install crash capture before any other launch work so startup crashes are recorded.
        let crashReportStore = CrashReportStore()
        CrashReportInstaller.install(store: crashReportStore, environment: .current())
        crashReportController = CrashReportController(store: crashReportStore)

        let inventoryCache = InstalledInventoryCache()
        // nil in every production launch, so both process-boundary seams below fall through to the
        // live wiring untouched.
        let uiTesting = BrewUITestingLaunchConfiguration.current()
        let languageDefaults = uiTesting == nil ? UserDefaults.standard : ProcessInfo.processInfo.environment[
            BrewUITestingEnvironmentKey.languagePreferencesDomain,
        ].flatMap(UserDefaults.init(suiteName:))
        _languagePreferences = State(initialValue: LanguagePreferences(
            defaults: languageDefaults,
            preferredLanguages: uiTesting == nil ? Locale.preferredLanguages : ["en"],
        ))
        // Writes this run's fixture tree into the app's own temp directory, before anything reads it.
        let fixtures = Self.installFixtures(uiTesting: uiTesting)
        let selfUpgradeKeyPrefix = Self.defaultsKeyPrefix(base: "selfUpgrade", fixtures: fixtures)
        // Before the caches are built: `makeCatalogueCache` sweeps every `UITesting.`-prefixed default.
        let launchOutcome = SelfUpgradeLaunchNotice(defaultsKeyPrefix: selfUpgradeKeyPrefix).consume()
        let catalogue = Self.makeCatalogueCache(fixtures: fixtures)
        let discoverAnalytics = Self.makeDiscoverAnalyticsCache(fixtures: fixtures)
        // One context for every brew invocation: command center, installed inventory and `brew config`.
        let executionContext = Self.executionContext(uiTesting: uiTesting, fixtures: fixtures)
        let center = SerialBrewCommandCenter(executionContext: executionContext)
        let apiClient = Self.makeAPIClient(uiTesting: uiTesting)
        let catalogueRepo = BrewCatalogueRepository(apiClient: apiClient, cache: catalogue)

        installedInventoryCache = inventoryCache
        catalogueCache = catalogue
        discoverAnalyticsCache = discoverAnalytics
        commandCenter = center
        commandFactory = LiveBrewMutatingCommandFactory()
        installedPackagesRepository = BrewInstalledPackagesRepository(
            executionContext: executionContext,
            cache: inventoryCache,
            commandCenter: center,
        )
        commandJobsRepository = BrewCommandJobsRepository(commandCenter: center)
        installedDependentsRepository = BrewInstalledDependentsRepository(cache: inventoryCache)
        catalogueRepository = catalogueRepo
        discoverPackagesRepository = BrewDiscoverPackagesRepository(
            apiClient: apiClient,
            catalogueRepository: catalogueRepo,
            cache: discoverAnalytics,
            defaultsKeyPrefix: Self.defaultsKeyPrefix(base: "DiscoverAnalytics", fixtures: fixtures),
        )
        doctorRepository = BrewDoctorRepository(commandCenter: center, executionContext: executionContext)
        configRepository = BrewConfigRepository(executionContext: executionContext)

        let selfUpgradeContext = SelfUpgradeLaunchContext(
            installedPackagesRepository: installedPackagesRepository,
            executionContext: executionContext,
            commandCenter: center,
            selfUpgradeKeyPrefix: selfUpgradeKeyPrefix,
            uiTesting: uiTesting,
            fixtures: fixtures,
            launchOutcome: launchOutcome,
        )
        #if DEBUG
            selfUpgradeCoordinator = Self.makeSelfUpgradeCoordinator(selfUpgradeContext, debugControl: selfUpgradeDebugControl)
        #else
            selfUpgradeCoordinator = Self.makeSelfUpgradeCoordinator(selfUpgradeContext)
        #endif

        NSWindow.allowsAutomaticWindowTabbing = false
    }

    /// Cleared at launch, so a previous run's ETag or refresh timestamp cannot decide this run's fetches.
    private static let uiTestingDefaultsPrefix = "UITesting."

    /// Fatal on failure by design: continuing without fixtures would surface later as a product bug.
    private static func installFixtures(
        uiTesting: BrewUITestingLaunchConfiguration?,
    ) -> BrewUITestingFixtureInstaller.Installation? {
        guard let uiTesting else {
            return nil
        }
        do {
            return try BrewUITestingFixtureInstaller.install(
                payload: uiTesting.payload,
                scenario: uiTesting.scenario,
            )
        } catch {
            fatalError("UI-test fixtures could not be installed: \(error)")
        }
    }

    /// Network seam. Under `-uiTesting` with a scenario, requests are served in-process by
    /// ``BrewUITestingStubURLProtocol`` on a private ephemeral session; otherwise this is `live()`.
    private static func makeAPIClient(uiTesting: BrewUITestingLaunchConfiguration?) -> any BrewAPIClient {
        guard let uiTesting, uiTesting.scenario != nil else {
            return URLSessionBrewAPIClient.live()
        }
        return URLSessionBrewAPIClient.stubbed(protocolClasses: [BrewUITestingStubURLProtocol.self])
    }

    /// Catalogue cache seam. Under `-uiTesting` the bytes land in the run's container, so fixtures
    /// cannot outlive the run or overwrite a real install's cache.
    private static func makeCatalogueCache(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> CatalogueCache {
        guard let fixtures else {
            return CatalogueCache()
        }
        clearUITestingDefaults()
        return CatalogueCache(
            cacheDirectoryURL: fixtures.containerURL.appendingPathComponent(
                "CatalogueCache",
                isDirectory: true,
            ),
            defaultsKeyPrefix: defaultsKeyPrefix(base: "CatalogueCache", fixtures: fixtures),
        )
    }

    /// Analytics cache seam. Same isolation rationale as ``makeCatalogueCache(fixtures:)``.
    private static func makeDiscoverAnalyticsCache(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> DiscoverAnalyticsCache {
        guard let fixtures else {
            return DiscoverAnalyticsCache()
        }
        return DiscoverAnalyticsCache(
            cacheDirectoryURL: fixtures.containerURL.appendingPathComponent(
                "DiscoverAnalytics",
                isDirectory: true,
            ),
            defaultsKeyPrefix: defaultsKeyPrefix(base: "DiscoverAnalytics", fixtures: fixtures),
        )
    }

    private static func defaultsKeyPrefix(
        base: String,
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> String {
        fixtures == nil ? base : uiTestingDefaultsPrefix + base
    }

    /// Carried forward, or the relaunched process comes up pointed at the real Homebrew mid-test.
    private static func relaunchArguments(uiTesting: BrewUITestingLaunchConfiguration?) -> [String] {
        guard uiTesting != nil else {
            return []
        }
        return [BrewUITestingEnvironmentKey.launchArgument, "YES"]
    }

    /// `fixturesRoot` is omitted: the relaunched app reinstalls the fixture tree into its own temp directory.
    private static func relaunchEnvironment(uiTesting: BrewUITestingLaunchConfiguration?) -> [String: String] {
        guard let uiTesting else {
            return [:]
        }
        var environment: [String: String] = [:]
        environment[BrewUITestingEnvironmentKey.scenario] = uiTesting.scenario
        environment[BrewUITestingEnvironmentKey.payload] = uiTesting.payload
        environment[BrewUITestingEnvironmentKey.languagePreferencesDomain] = ProcessInfo.processInfo.environment[
            BrewUITestingEnvironmentKey.languagePreferencesDomain,
        ]
        return environment
    }

    private static func upgradeEnvironment(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
        uiTesting: BrewUITestingLaunchConfiguration?,
    ) -> [String: String] {
        guard let fixtures, let scenario = uiTesting?.scenario else {
            return [:]
        }
        return [
            BrewUITestingEnvironmentKey.fixturesRoot: fixtures.rootURL.path,
            BrewUITestingEnvironmentKey.scenario: scenario,
        ]
    }

    /// Under `-uiTesting` the transcript stays in the run's container, clear of a real install's log.
    private static func selfUpgradeLogFileURL(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> URL {
        guard let fixtures else {
            return SelfUpgradeHandoffDefaults.productionLogFileURL()
        }
        return fixtures.containerURL.appendingPathComponent("self-upgrade.log")
    }

    private static func clearUITestingDefaults() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(uiTestingDefaultsPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Shell seam. A UI-test launch that installed no fake resolves nothing, rather than falling back
    /// to the machine's real Homebrew.
    private static func executionContext(
        uiTesting: BrewUITestingLaunchConfiguration?,
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> BrewCommandExecutionContext {
        guard uiTesting != nil else {
            return .live()
        }
        return .uiTesting(brewURL: fixtures?.fakeBrewURL)
    }

    private func refreshNativeMenus() {
        standardAppCommandState.refresh()
        standardEditingState.refresh()
        nativeMenuRefresh.request(localization: languagePreferences.localization)
    }

    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
            MainWindowView()
                .environment(\.brewCommandCenter, commandCenter)
                .environment(\.mutatingCommandFactory, commandFactory)
                .environment(\.installedPackagesRepository, installedPackagesRepository)
                .environment(\.commandJobsRepository, commandJobsRepository)
                .environment(\.installedDependentsRepository, installedDependentsRepository)
                .environment(\.catalogueRepository, catalogueRepository)
                .environment(\.discoverPackagesRepository, discoverPackagesRepository)
                .environment(\.doctorRepository, doctorRepository)
                .environment(\.configRepository, configRepository)
                .environment(\.selfUpgradeCoordinator, selfUpgradeCoordinator)
                .task {
                    async let catalogue: Void = catalogueCache.prepare()
                    async let analytics: Void = discoverAnalyticsCache.prepare()
                    _ = await (catalogue, analytics)
                    await discoverPackagesRepository.load()
                }
                .task {
                    await installedPackagesRepository.load()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Mark the config + brew.env caches stale on return-to-foreground so the next visit
                    // to the Configuration tab triggers a silent revalidation (stale value stays on
                    // screen during the refetch). No work is done if the user never opens the tab.
                    guard oldPhase == .background, newPhase == .active else {
                        return
                    }
                    configRepository.invalidate()
                }
                .frame(
                    minWidth: BrewLayout.minWindowWidth,
                    minHeight: BrewLayout.minWindowHeight,
                )
                .crashReportSheet(controller: crashReportController)
                .environment(\.locale, languagePreferences.localization.locale)
                .environment(\.layoutDirection, languagePreferences.localization.layoutDirection)
                .environment(\.brewLocalization, languagePreferences.localization)
                .task(id: languagePreferences.localization.locale.identifier) {
                    // 等 SwiftUI 完成本轮 Commands 更新，只改现有原生菜单的标题。
                    await Task.yield()
                    refreshNativeMenus()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didUpdateNotification)) { _ in
                    // 焦点或选择变化后更新快捷键可用性，不要求先打开菜单。
                    standardEditingState.refresh()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                    refreshNativeMenus()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
                    refreshNativeMenus()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSMenu.didChangeItemNotification)) { _ in
                    refreshNativeMenus()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSMenu.didAddItemNotification)) { _ in
                    refreshNativeMenus()
                }
        }
        .defaultSize(
            width: BrewLayout.defaultWindowWidth,
            height: BrewLayout.defaultWindowHeight,
        )
        .commands {
            StandardEditingCommands(localization: languagePreferences.localization, state: standardEditingState)
            StandardAppCommands(localization: languagePreferences.localization, mainWindowID: Self.mainWindowID, state: standardAppCommandState)
            LanguageCommands(preferences: languagePreferences)
            SearchCommands(localization: languagePreferences.localization)
            SidebarCommands(localization: languagePreferences.localization)
            RefreshCommands(localization: languagePreferences.localization)
            ConsoleCommands(localization: languagePreferences.localization)

            // Replace the default "Homebrew Help" item (which points at a
            // non-existent help book) with a link to the online documentation.
            CommandGroup(replacing: .help) {
                Link(languagePreferences.localization.string("Homebrew Documentation"), destination: Self.documentationURL)
                Link(languagePreferences.localization.string("Report an Issue…"), destination: Self.reportIssueURL)
            }
        }
        #if DEBUG
        .commands {
                DebugMenuCommands(selfUpgradeControl: selfUpgradeDebugControl)
            }
        #endif
    }
}

/// Bundled so the two `makeSelfUpgradeCoordinator` overloads don't each carry seven parameters.
private struct SelfUpgradeLaunchContext {
    let installedPackagesRepository: BrewInstalledPackagesRepository
    let executionContext: BrewCommandExecutionContext
    let commandCenter: any BrewCommandCenter
    let selfUpgradeKeyPrefix: String
    let uiTesting: BrewUITestingLaunchConfiguration?
    let fixtures: BrewUITestingFixtureInstaller.Installation?
    let launchOutcome: SelfUpgradeOutcome?
}

extension BrewApp {
    #if DEBUG
        /// A dev build is never the installed cask, so DEBUG wraps both detection and the handoff.
        private static func makeSelfUpgradeCoordinator(
            _ context: SelfUpgradeLaunchContext,
            debugControl: SelfUpgradeDebugControl,
        ) -> SelfUpgradeCoordinator {
            let statusProvider = DebugSelfUpgradeStatusProvider(
                base: BrewSelfUpgradeStatusProvider(
                    inventory: context.installedPackagesRepository,
                    versionReader: BundleAppVersionReader(),
                ),
                control: debugControl,
            )
            let handoff = DebugSelfUpgradeHandoff(
                base: makeHelperHandoff(context),
                isSimulatingUpgrade: { debugControl.simulateUpgradeAvailable },
            )
            return makeCoordinator(statusProvider: statusProvider, handoff: handoff, context)
        }
    #else
        private static func makeSelfUpgradeCoordinator(_ context: SelfUpgradeLaunchContext) -> SelfUpgradeCoordinator {
            let statusProvider = BrewSelfUpgradeStatusProvider(
                inventory: context.installedPackagesRepository,
                versionReader: BundleAppVersionReader(),
            )
            let handoff = makeHelperHandoff(context)
            return makeCoordinator(statusProvider: statusProvider, handoff: handoff, context)
        }
    #endif

    /// The same locator and login-shell decision every other brew invocation goes through.
    private static func makeHelperHandoff(_ context: SelfUpgradeLaunchContext) -> HelperSelfUpgradeHandoff {
        HelperSelfUpgradeHandoff(
            brewExecutableURL: { try context.executionContext.brewExecutableURL() },
            commandCenter: context.commandCenter,
            usesLoginShell: context.uiTesting == nil,
            defaultsKeyPrefix: context.selfUpgradeKeyPrefix,
            relaunchArguments: relaunchArguments(uiTesting: context.uiTesting),
            relaunchEnvironment: relaunchEnvironment(uiTesting: context.uiTesting),
            upgradeEnvironment: upgradeEnvironment(fixtures: context.fixtures, uiTesting: context.uiTesting),
            logFileURL: selfUpgradeLogFileURL(fixtures: context.fixtures),
        )
    }

    private static func makeCoordinator(
        statusProvider: any SelfUpgradeStatusProviding,
        handoff: any SelfUpgradeHandoff,
        _ context: SelfUpgradeLaunchContext,
    ) -> SelfUpgradeCoordinator {
        let coordinator = SelfUpgradeCoordinator(
            statusProvider: statusProvider,
            preferences: UserDefaultsSelfUpgradePreferences(defaultsKeyPrefix: context.selfUpgradeKeyPrefix),
            handoff: handoff,
        )
        coordinator.registerLaunchOutcome(context.launchOutcome)
        return coordinator
    }
}

/// 合并 SwiftUI 重新生成菜单时的一批通知；自身标题写入不再递归调度。
@MainActor
private final class NativeMenuRefresh {
    private var isScheduled = false
    private var isApplying = false
    private var localization = AppLocalization()

    func request(localization: AppLocalization) {
        self.localization = localization
        guard !isApplying, !isScheduled else { return }
        isScheduled = true
        // 菜单打开时处于 event-tracking run loop；普通 Task 可能等到菜单关闭才执行。
        RunLoop.main.perform(inModes: [.common]) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isApplying = true
                NativeMenuLocalization.applyStandard(to: NSApp, localization: self.localization)
                self.isApplying = false
                self.isScheduled = false
            }
        }
    }
}
