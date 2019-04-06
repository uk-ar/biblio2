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

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        // Use Firebase library to configure APIs
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        let extensionItem: NSExtensionItem = self.extensionContext?.inputItems.first as! NSExtensionItem
        let itemProvider = extensionItem.attachments?.first as! NSItemProvider
        
        let puclicURL = String(kUTTypeURL)  // "public.url"
//        var ref: DocumentReference? = nil
//
        print("fireauth:which")
        var user = Auth.auth().currentUser
        if (user == nil){
            print("fireauth:no current")
            Auth.auth().signInAnonymously() { (authResult, error) in
                user = authResult?.user
                let isAnonymous = user?.isAnonymous  // true
                let uid = user?.uid
                print("fireauth:user:",user)
                print("fireauth:uid:",uid)
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            }
        }else{
            print("fireauth:current")
            print("fireauth:user:",user)
            print("fireauth:uid:",user?.uid)
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
        }
        
        
        let db = Firestore.firestore()
        // shareExtension で NSURL を取得
        if itemProvider.hasItemConformingToTypeIdentifier(puclicURL) {
            itemProvider.loadItem(forTypeIdentifier: puclicURL, options: nil, completionHandler: { (item, error) in
                // NSURLを取得する
                if let url: NSURL = item as? NSURL {
                    // ----------
                    // 保存処理
                    // ----------
                    db.collection("books").document("isbnXX").setData([
                        "title": "GitHub",
                        "url": url.absoluteString ?? ""
                    ]) { err in
                        if let err = err {
                            print("fireauth:Error writing document: \(err)")
                        } else {
                            print("fireauth:Document successfully written!")
                            //self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
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
