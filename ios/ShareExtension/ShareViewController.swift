//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by 有澤 悠紀 on 2019/03/30.
//  Copyright © 2019 The Chromium Authors. All rights reserved.
//

import UIKit
import Social
import Firebase
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {
    /** @var handle
     @brief The handler for the auth state listener, to allow cancelling later.
     */
    //https://github.com/firebase/snippets-ios/blob/7af7f641151501af427fc4ef7c421b0ba357ce27/firestore/swift/firestore-smoketest/ViewController.swift#L140-L152
    var db: Firestore!
    var handle: AuthStateDidChangeListenerHandle?
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            db = Firestore.firestore()
        }
        // [START auth_listener]
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            // [START_EXCLUDE]
            if (user == nil) {
                print("fireauth:no current")
                Auth.auth().signInAnonymously() { (authResult, error) in
                    if let user = authResult?.user {
                        let isAnonymous = user.isAnonymous  // true
                        let uid = user.uid
                        self.db.collection("users").document(uid).setData([
                            "isAnonymous": isAnonymous,
                            ])
                    }
                }
            }else{
                 print("fireauth:current")
            }
            // [END_EXCLUDE]
        }
        // [END auth_listener]
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // [START remove_auth_listener]
        Auth.auth().removeStateDidChangeListener(handle!)
        // [END remove_auth_listener]
    }
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        // Use Firebase library to configure APIs


        let extensionItem: NSExtensionItem = self.extensionContext?.inputItems.first as! NSExtensionItem
        let itemProvider = extensionItem.attachments?.first as! NSItemProvider
        
        let puclicURL = String(kUTTypeURL)  // "public.url"
//        var ref: DocumentReference? = nil
//
        let user = Auth.auth().currentUser
        guard let uid = user?.uid else{
            return
        }
        print("fireauth:user:",user)
        print("fireauth:uid:",uid)
        let userRef: DocumentReference? = db.collection("users").document(uid)
        // shareExtension で NSURL を取得
        if itemProvider.hasItemConformingToTypeIdentifier(puclicURL) {
            itemProvider.loadItem(forTypeIdentifier: puclicURL, options: nil, completionHandler: { (item, error) in
                // NSURLを取得する
                if let url: NSURL = item as? NSURL {
                    // ----------
                    // 保存処理
                    // ----------
                    self.db.collection("posts").addDocument(data: [
                        "author": userRef,
                        "url": url.absoluteString ?? ""
                        ]){ err in
                        if let err = err {
                            print("fireauth:Error writing document: \(err)")
                        } else {
                            print("fireauth:Document successfully written!")
                            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                        }
                    }
                }
            })
        }
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        //self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

}
