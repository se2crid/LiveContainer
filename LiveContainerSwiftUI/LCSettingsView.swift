//
//  LCSettingsView.swift
//  LiveContainerSwiftUI
//
//  Created by s s on 2024/8/21.
//

import Foundation
import SwiftUI

enum PatchChoice {
    case cancel
    case autoPath
    case archiveOnly
}

enum JITEnablerType : Int {
    case SideJITServer = 0
    case StkiJIT = 1
    case JITStreamerEBLegacy = 2
    case StikJITLC = 3
    case SideStore = 4
}

struct LCSettingsView: View {
    @State var errorShow = false
    @State var errorInfo = ""
    @State var successShow = false
    @State var successInfo = ""
    
    @Binding var appDataFolderNames: [String]

    @StateObject private var patchAltStoreAlert = AlertHelper<PatchChoice>()
    @StateObject private var installLC2Alert = AlertHelper<PatchChoice>()
    @State private var isAltStorePatched = false
    @State private var certificateDataFound = false
    
    @StateObject private var certificateImportAlert = YesNoHelper()
    @StateObject private var certificateRemoveAlert = YesNoHelper()
    @StateObject private var certificateImportFileAlert = AlertHelper<URL>()
    @StateObject private var certificateImportPasswordAlert = InputHelper()
    @State private var showShareSheet = false
    @State private var shareURL : URL? = nil
    
    @State var isJitLessEnabled = false
    @AppStorage("LCFrameShortcutIcons") var frameShortIcon = false
    @AppStorage("LCSwitchAppWithoutAsking") var silentSwitchApp = false
    @AppStorage("LCOpenWebPageWithoutAsking") var silentOpenWebPage = false
    @AppStorage("LCDontSignApp", store: LCUtils.appGroupUserDefault) var dontSignApp = false
    @AppStorage("LCStrictHiding", store: LCUtils.appGroupUserDefault) var strictHiding = false
    @AppStorage("dynamicColors") var dynamicColors = true
    
    @AppStorage("LCSideJITServerAddress", store: LCUtils.appGroupUserDefault) var sideJITServerAddress : String = ""
    @AppStorage("LCDeviceUDID", store: LCUtils.appGroupUserDefault) var deviceUDID: String = ""
    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault) var JITEnabler: JITEnablerType = .SideJITServer
    
    @State var store : Store = .Unknown
    
    @AppStorage("LCLoadTweaksToSelf") var injectToLCItelf = false
    @AppStorage("LCIgnoreJITOnLaunch") var ignoreJITOnLaunch = false
    @AppStorage("selected32BitLayer") var liveExec32Path : String = ""
    @AppStorage("LCKeepSelectedWhenQuit") var keepSelectedWhenQuit = false
    @AppStorage("LCWaitForDebugger") var waitForDebugger = false
    
    @EnvironmentObject private var sharedModel : SharedModel
    
    let storeName = LCUtils.getStoreName()
    
    init(appDataFolderNames: Binding<[String]>) {
        _isJitLessEnabled = State(initialValue: LCUtils.certificatePassword() != nil)
        _store = State(initialValue: LCUtils.store())
        
        _appDataFolderNames = appDataFolderNames
    }
    
    var body: some View {
        VStack {
            Text("Settings")
            // Simplified subviews or logic here
        }
    }
    
    func installAnotherLC() async {
        if !LCUtils.isAppGroupAltStoreLike() {
            errorInfo = "lc.settings.unsupportedInstallMethod".loc
            errorShow = true
            return;
        }
        
        guard let result = await installLC2Alert.open(), result != .cancel else {
            return
        }
        
        do {
            let packedIpaUrl = try LCUtils.archiveIPA(withBundleName: "LiveContainer2")
            
            shareURL = packedIpaUrl
            showShareSheet = true
            
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
        }
    }
    
    func openGitHub() {
        UIApplication.shared.open(URL(string: "https://github.com/khanhduytran0/LiveContainer")!)
    }
    
    func openGitHub2() {
        UIApplication.shared.open(URL(string: "https://github.com/hugeBlack/LiveContainer")!)
    }
    
    func openTwitter() {
        UIApplication.shared.open(URL(string: "https://twitter.com/TranKha50277352")!)
    }
    
    func updateSideStorePatchStatus() {
        let fm = FileManager()
        
        certificateDataFound = LCUtils.certificateData() != nil
        
        guard let appGroupPath = LCUtils.appGroupPath() else {
            isAltStorePatched = false
            return
        }
        var patchDylibPath : String;
        if (LCUtils.store() == .AltStore) {
            patchDylibPath = appGroupPath.appendingPathComponent("Apps/com.rileytestut.AltStore/App.app/Frameworks/AltStoreTweak.dylib").path
        } else {
            patchDylibPath = appGroupPath.appendingPathComponent("Apps/com.SideStore.SideStore/App.app/Frameworks/AltStoreTweak.dylib").path
        }
        
        if(fm.fileExists(atPath: patchDylibPath)) {
            isAltStorePatched = true
        } else {
            isAltStorePatched = false
        }
    }
    
    func patchAltStore() async {
        guard let result = await patchAltStoreAlert.open(), result != .cancel else {
            return
        }
        
        do {
            let altStoreIpa = try LCUtils.archiveTweakedAltStore()
            let storeInstallUrl = String(format: LCUtils.storeInstallURLScheme(), altStoreIpa.absoluteString)
            if(result == .archiveOnly) {
                let movedAltStoreIpaUrl = LCPath.docPath.appendingPathComponent("Patched\(store == .SideStore ? "SideStore" : "AltStore").ipa")
                try FileManager.default.moveItem(at: altStoreIpa, to: movedAltStoreIpaUrl)
                successInfo = "lc.settings.patchStoreArchiveSuccess %@ %@".localizeWithFormat(storeName, storeName)
                successShow = true
            } else {
                await UIApplication.shared.open(URL(string: storeInstallUrl)!)
            }
            

        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
        }
        
    }
    
    func export() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 1. Copy embedded.mobileprovision from the main bundle to Documents
        if let embeddedURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") {
            let destinationURL = documentsURL.appendingPathComponent("embedded.mobileprovision")
            do {
                try fileManager.copyItem(at: embeddedURL, to: destinationURL)
                print("Successfully copied embedded.mobileprovision to Documents.")
            } catch {
                print("Error copying embedded.mobileprovision: \(error)")
            }
        } else {
            print("embedded.mobileprovision not found in the main bundle.")
        }
        
        // 2. Read "certData" from UserDefaults and save to cert.p12 in Documents
        if let certData = LCUtils.certificateData() {
            let certFileURL = documentsURL.appendingPathComponent("cert.p12")
            do {
                try certData.write(to: certFileURL)
                print("Successfully wrote certData to cert.p12 in Documents.")
            } catch {
                print("Error writing certData to cert.p12: \(error)")
            }
        } else {
            print("certData not found in UserDefaults.")
        }
        
        // 3. Read "certPassword" from UserDefaults and save to pass.txt in Documents
        if let certPassword = LCUtils.certificatePassword() {
            let passwordFileURL = documentsURL.appendingPathComponent("pass.txt")
            do {
                try certPassword.write(to: passwordFileURL, atomically: true, encoding: .utf8)
                print("Successfully wrote certPassword to pass.txt in Documents.")
            } catch {
                print("Error writing certPassword to pass.txt: \(error)")
            }
        } else {
            print("certPassword not found in UserDefaults.")
        }
    }
    
    func exportMainExecutable() {
        let url = Bundle.main.executableURL!
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)
            try fileManager.copyItem(at: url, to: destinationURL)
            print("Successfully copied main executable to Documents.")
        } catch {
            print("Error copying main executable \(error)")
        }
    }
    
    func importCertificate() async {
        guard let doImport = await certificateImportAlert.open(), doImport else {
            return
        }
        guard let certificateURL = await certificateImportFileAlert.open() else {
            return
        }
        guard let certificatePassword = await certificateImportPasswordAlert.open() else {
            return
        }
        let certificateData : Data
        do {
            certificateData = try Data(contentsOf: certificateURL)
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
            return
        }
        
        guard let _ = LCUtils.getCertTeamId(withKeyData: certificateData, password: certificatePassword) else {
            errorInfo = "lc.settings.invalidCertError".loc
            errorShow = true
            return
        }
        UserDefaults.standard.set(certificatePassword, forKey: "LCCertificatePassword")
        UserDefaults.standard.set(certificateData, forKey: "LCCertificateData")
        UserDefaults.standard.set(true, forKey: "LCCertificateImported")
        sharedModel.certificateImported = true
    }
    
    func importCertificateFromSideStore() async {
        guard let url = URL(string: "\(storeName.lowercased())://certificate?callback_template=livecontainer%3A%2F%2Fcertificate%3Fcert%3D%24%28BASE64_CERT%29%26password%3D%24%28PASSWORD%29") else {
            errorInfo = "Failed to initialize certificate import URL."
            errorShow = true
            return
        }
        await UIApplication.shared.open(url)
    }
    func onSideStoreCertificateCallback(certificateData: Data, password: String) {
        LCUtils.appGroupUserDefault.set(certificateData, forKey: "LCCertificateData")
        LCUtils.appGroupUserDefault.set(password, forKey: "LCCertificatePassword")
        LCUtils.appGroupUserDefault.set(NSDate.now, forKey: "LCCertificateUpdateDate")
    }
    
    func removeCertificate() async {
        guard let doRemove = await certificateRemoveAlert.open(), doRemove else {
            return
        }
        UserDefaults.standard.set(false, forKey: "LCCertificateImported")
        UserDefaults.standard.set(nil, forKey: "LCCertificatePassword")
        UserDefaults.standard.set(nil, forKey: "LCCertificateData")
        sharedModel.certificateImported = false
    }
    
    func nukeSideStore() async {
        guard let doRemove = await certificateRemoveAlert.open(), doRemove else {
            return
        }
        do {
            let fm = FileManager.default
            let sidestoreAppGroupURL = LCPath.lcGroupDocPath.deletingLastPathComponent()
            try fm.removeItem(at: sidestoreAppGroupURL.appendingPathComponent("Database"))
            try fm.removeItem(at: sidestoreAppGroupURL.appendingPathComponent("Apps"))
        } catch {
            print("wtf \(error)")
        }
    }
    
    func exportDyld() {
        let url = URL(fileURLWithPath: "/usr/lib/dyld")
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)
            try fileManager.copyItem(at: url, to: destinationURL)
            print("Successfully copied dyld to Documents.")
        } catch {
            print("Error copying dyld \(error)")
        }
    }
}
