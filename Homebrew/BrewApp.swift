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
import BrewFeatureInstalled
import BrewFeatureSelfUpdate
import BrewNetworking
import BrewRepositories
import BrewRepositoryInterfaces
import BrewSelfUpdateContract
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
    private let selfUpdateCoordinator: SelfUpdateCoordinator
    #if DEBUG
        private let selfUpdateDebugControl = SelfUpdateDebugControl()
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
        let selfUpdateKeyPrefix = Self.defaultsKeyPrefix(base: "selfUpdate", fixtures: fixtures)
        // Consumed *before* the caches are built: `makeCatalogueCache` sweeps every `UITesting.`-prefixed
        // default, which under `-uiTesting` includes the notice the update helper just wrote.
        let launchOutcome = SelfUpdateLaunchNotice(defaultsKeyPrefix: selfUpdateKeyPrefix).consume()
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

        let realStatusProvider = BrewSelfUpdateStatusProvider(
            inventory: installedPackagesRepository,
            versionReader: BundleAppVersionReader(),
        )
        // A dev build never has its own cask outdated, so DEBUG wraps the provider with the simulator.
        #if DEBUG
            let statusProvider: any SelfUpdateStatusProviding = DebugSelfUpdateStatusProvider(
                base: realStatusProvider,
                control: selfUpdateDebugControl,
            )
        #else
            let statusProvider: any SelfUpdateStatusProviding = realStatusProvider
        #endif
        // A closure, not a value: the DEBUG menu can flip this mid-session.
        let simulationRequestedAtLaunch = uiTesting?.usesFakeSelfUpdate == true
        let simulated = SelfUpdateHandoffDefaults.simulatedUpgradeDuration
        #if DEBUG
            let debugControl = selfUpdateDebugControl
            let simulatedUpgradeDuration: @MainActor () -> TimeInterval? = {
                simulationRequestedAtLaunch || debugControl.simulateUpdateHandoff ? simulated : nil
            }
        #else
            let simulatedUpgradeDuration: @MainActor () -> TimeInterval? = {
                simulationRequestedAtLaunch ? simulated : nil
            }
        #endif
        let coordinator = SelfUpdateCoordinator(
            statusProvider: statusProvider,
            preferences: UserDefaultsSelfUpdatePreferences(defaultsKeyPrefix: selfUpdateKeyPrefix),
            handoff: HelperSelfUpdateHandoff(
                // The same locator every other brew invocation goes through, so under `-uiTesting` the
                // helper upgrades through the fake `brew` rather than the machine's real one.
                brewExecutableURL: { try executionContext.brewExecutableURL() },
                simulatedUpgradeDuration: simulatedUpgradeDuration,
                defaultsKeyPrefix: selfUpdateKeyPrefix,
                relaunchArguments: Self.relaunchArguments(uiTesting: uiTesting),
                relaunchEnvironment: Self.relaunchEnvironment(uiTesting: uiTesting),
                upgradeEnvironment: Self.upgradeEnvironment(fixtures: fixtures, uiTesting: uiTesting),
                logFileURL: Self.selfUpdateLogFileURL(fixtures: fixtures),
            ),
        )
        coordinator.registerLaunchOutcome(launchOutcome)
        selfUpdateCoordinator = coordinator

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

    /// A UI-test relaunch has to carry the launch flag forward, or the new process comes up pointed at the
    /// real Homebrew mid-test.
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
        if uiTesting.usesFakeSelfUpdate {
            environment[BrewUITestingEnvironmentKey.fakeSelfUpdate] = "1"
        }
        return environment
    }

    /// The fake `brew` reads the fixture tree out of its environment, and the helper is spawned by this
    /// process but outlives it — so what `setenv` published here has to travel in the spec. Empty in
    /// production, where the real `brew` needs nothing pinned.
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

    /// Under `-uiTesting` the transcript lands in the run's container, so a test cannot overwrite the log
    /// of a real install's last self-update.
    private static func selfUpdateLogFileURL(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> URL {
        guard let fixtures else {
            return SelfUpdateHandoffDefaults.productionLogFileURL()
        }
        return fixtures.containerURL.appendingPathComponent("self-update.log")
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
            MainWindowView(selfUpdateCoordinator: selfUpdateCoordinator)
                .environment(\.brewCommandCenter, commandCenter)
                .environment(\.mutatingCommandFactory, commandFactory)
                .environment(\.installedPackagesRepository, installedPackagesRepository)
                .environment(\.commandJobsRepository, commandJobsRepository)
                .environment(\.installedDependentsRepository, installedDependentsRepository)
                .environment(\.catalogueRepository, catalogueRepository)
                .environment(\.discoverPackagesRepository, discoverPackagesRepository)
                .environment(\.doctorRepository, doctorRepository)
                .environment(\.configRepository, configRepository)
                .environment(\.selfUpdateCoordinator, selfUpdateCoordinator)
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
                DebugMenuCommands(selfUpdateControl: selfUpdateDebugControl)
            }
        #endif
    }
}
