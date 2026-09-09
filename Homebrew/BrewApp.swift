//
//  BrewApp.swift
//  Brew
//
//  Created by Graeme Arthur on 6/3/2026.
//

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

    var body: some Scene {
        WindowGroup {
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
        }
        .defaultSize(
            width: BrewLayout.defaultWindowWidth,
            height: BrewLayout.defaultWindowHeight,
        )
        .commands {
            SearchCommands()
            SidebarCommands()
            RefreshCommands()
            ConsoleCommands()

            // Replace the default "Homebrew Help" item (which points at a
            // non-existent help book) with a link to the online documentation.
            CommandGroup(replacing: .help) {
                Link("Homebrew Documentation", destination: Self.documentationURL)
                Link("Report an Issue…", destination: Self.reportIssueURL)
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
