import CarPlay
import UIKit
import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CPApplicationDelegate {
    var window: UIWindow?
    var carPlayInterfaceController: CPInterfaceController?
    var carWindow: CPWindow?

    private static var urlStrToOpen: String? = nil
    private static var openUrlStrFunc: ((String) async -> Void)?
    private static var installUrl: String? = nil
    private static var installFromUrlStrFunc: ((String) async -> Void)?
    private static var bundleToLaunch: String? = nil
    private static var containerToLaunch: String? = nil
    private static var launchAppFunc: ((String, String?) async -> Void)?

    private static var certData: Data? = nil
    private static var certPassword: String? = nil
    private static var importSideStoreCertFunc: ((Data, String) async -> Void)?

    public static func setOpenUrlStrFunc(handler: @escaping ((String) async -> Void)){
        self.openUrlStrFunc = handler
        if let urlStrToOpen = self.urlStrToOpen {
            Task { await handler(urlStrToOpen) }
            self.urlStrToOpen = nil
        } else if let urlStr = UserDefaults.standard.string(forKey: "webPageToOpen") {
            UserDefaults.standard.removeObject(forKey: "webPageToOpen")
            Task { await handler(urlStr) }
        }
    }

    public static func setInstallFromUrlStrFunc(handler: @escaping ((String) async -> Void)){
        self.installFromUrlStrFunc = handler
        if let installUrl = self.installUrl {
            Task { await handler(installUrl) }
            self.urlStrToOpen = nil
        }
    }

    public static func setLaunchAppFunc(handler: @escaping ((String, String?) async -> Void)){
        self.launchAppFunc = handler
        if let bundleToLaunch = self.bundleToLaunch {
            Task { await handler(bundleToLaunch, containerToLaunch) }
            self.bundleToLaunch = nil
        }
    }

    public static func setImportSideStoreCertFunc(handler: @escaping ((Data, String) async -> Void)){
        self.importSideStoreCertFunc = handler
        if let certData, let certPassword {
            Task { await handler(certData, certPassword) }
            self.bundleToLaunch = nil
        }
    }

    private static func openWebPage(urlStr: String) {
        if openUrlStrFunc == nil {
            urlStrToOpen = urlStr
        } else {
            Task { await openUrlStrFunc!(urlStr) }
        }
    }

    private static func launchApp(bundleId: String, container: String?) {
        if launchAppFunc == nil {
            bundleToLaunch = bundleId
            containerToLaunch = container
        } else {
            Task { await launchAppFunc!(bundleId, container) }
        }
    }

    private static func installAppFromUrl(urlStr: String) {
        if installFromUrlStrFunc == nil {
            installUrl = urlStr
        } else {
            Task { await installFromUrlStrFunc!(urlStr) }
        }
    }

    private static func importSideStoreCert(certData: Data, password: String) {
        if importSideStoreCertFunc == nil {
            self.certData = certData
            self.certPassword = password
        } else {
            Task { await importSideStoreCertFunc!(certData, password) }
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        let contentView = LCTabView()
        window.rootViewController = UIHostingController(rootView: contentView)
        window.makeKeyAndVisible()
        application.shortcutItems = nil
        UserDefaults.standard.removeObject(forKey: "LCNeedToAcquireJIT")

        // Register for CarPlay
        CPApplication.shared.delegate = self
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // MARK: - CPApplicationDelegate
    func application(_ application: UIApplication, didConnectCarInterfaceController interfaceController: CPInterfaceController, to window: CPWindow) {
        self.carPlayInterfaceController = interfaceController
        self.carWindow = window

        // Setup CarPlay interface
        let template = CPListTemplate(title: "LiveContainer", sections: [
            CPListSection(items: [
                CPListItem(text: "App 1", detailText: "Details for App 1", handler: { _, completion in
                    // Handle selection
                    completion()
                }),
                CPListItem(text: "App 2", detailText: "Details for App 2", handler: { _, completion in
                    // Handle selection
                    completion()
                })
            ])
        ])

        interfaceController.setRootTemplate(template, animated: true)
    }

    func application(_ application: UIApplication, didDisconnectCarInterfaceController interfaceController: CPInterfaceController, from window: CPWindow) {
        self.carPlayInterfaceController = nil
        self.carWindow = nil
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        if url.isFileURL {
            AppDelegate.installAppFromUrl(urlStr: url.absoluteString)
            return true
        }

        if url.host == "open-web-page" || url.host == "open-url" {
            if let urlComponent = URLComponents(url: url, resolvingAgainstBaseURL: false), let queryItem = urlComponent.queryItems?.first {
                if queryItem.value?.isEmpty ?? true {
                    return true
                }

                if let decodedData = Data(base64Encoded: queryItem.value ?? ""),
                   let decodedUrl = String(data: decodedData, encoding: .utf8) {
                    AppDelegate.openWebPage(urlStr: decodedUrl)
                }
            }
        } else if url.host == "livecontainer-launch" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var bundleId : String? = nil
                var containerName : String? = nil
                for queryItem in components.queryItems ?? [] {
                    if queryItem.name == "bundle-name", let bundleId1 = queryItem.value {
                        bundleId = bundleId1
                    } else if queryItem.name == "container-folder-name", let containerName1 = queryItem.value {
                        containerName = containerName1
                    }
                }
                if let bundleId, bundleId != "ui"{
                    AppDelegate.launchApp(bundleId: bundleId, container: containerName)
                }
            }
        } else if url.host == "install" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var installUrl : String? = nil
                for queryItem in components.queryItems ?? [] {
                    if queryItem.name == "url", let installUrl1 = queryItem.value {
                        installUrl = installUrl1
                    }
                }
                if let installUrl {
                    AppDelegate.installAppFromUrl(urlStr: installUrl)
                }
            }
        } else if url.host == "certificate" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name.lowercased()] = $1.value } ?? [:]
                guard let encodedCert = queryItems["cert"]?.removingPercentEncoding,
                      let password = queryItems["password"],
                      let certData = Data(base64Encoded: encodedCert)
                else { return false }

                AppDelegate.importSideStoreCert(certData: certData, password: password)

            }
        }

        return false
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Fix launching app if user opens JIT waiting dialog and kills the app. Won't trigger normally.
        if DataManager.shared.model.isJITModalOpen && !UserDefaults.standard.bool(forKey: "LCKeepSelectedWhenQuit"){
            UserDefaults.standard.removeObject(forKey: "selected")
            UserDefaults.standard.removeObject(forKey: "selectedContainer")
        }

        if (UserDefaults.standard.object(forKey: "LCLastLanguages") != nil) {
            // recover livecontainer's own language
            UserDefaults.standard.set(UserDefaults.standard.object(forKey: "LCLastLanguages"), forKey: "AppleLanguages")
            UserDefaults.standard.removeObject(forKey: "LCLastLanguages")
        }
    }
}
