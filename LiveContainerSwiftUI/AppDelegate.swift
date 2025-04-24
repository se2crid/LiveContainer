import CarPlay
import UIKit
import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var carPlayInterfaceController: CPInterfaceController?
    var carWindow: CPWindow?

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

    // MARK: - CarPlay Integration
    func setupCarPlayInterface() {
        guard let interfaceController = carPlayInterfaceController else { return }

        let listItem1 = CPListItem(text: "App 1", detailText: "Details for App 1")
        let listItem2 = CPListItem(text: "App 2", detailText: "Details for App 2")

        let section = CPListSection(items: [listItem1, listItem2])
        let listTemplate = CPListTemplate(title: "LiveContainer", sections: [section])

        interfaceController.setRootTemplate(listTemplate, animated: true)
    }

    func application(_ application: UIApplication, didConnectCarInterfaceController interfaceController: CPInterfaceController, to window: CPWindow) {
        self.carPlayInterfaceController = interfaceController
        self.carWindow = window
        setupCarPlayInterface()
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
