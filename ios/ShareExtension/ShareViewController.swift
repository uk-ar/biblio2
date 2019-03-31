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
        var ref: DocumentReference? = nil
        //var ref: DatabaseReference!
        //let conditionRef =
        // クラウド上で、ノード condition に変更があった場合のコールバック処理
        //conditionRef.observe(.value) { (snap: DataSnapshot) in
        //    print("ノードの値が変わりました！: \((snap.value as AnyObject).description)")
        //}
        let db = Firestore.firestore()
        db.collection("books").getDocuments() { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                for document in querySnapshot!.documents {
                    print("\(document.documentID) => \(document.data())")
                }
            }
        }
//        ref = Database.database().reference()
//        //ref.child("books").observeSingleEvent(of: .value, with: { (snapshot) in
//        ref.child("books").observeSingleEvent(of: .value, with: { (snapshot) in
//            // Get user value
//            let value = snapshot.value as? NSDictionary
//            //value = value?["url"] as? String ?? ""
//            print("value \(value!)")
//            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
//        })
        // shareExtension で NSURL を取得
//        if itemProvider.hasItemConformingToTypeIdentifier(puclicURL) {
//            itemProvider.loadItem(forTypeIdentifier: puclicURL, options: nil, completionHandler: { (item, error) in
//                // NSURLを取得する
//                if let url: NSURL = item as? NSURL {
//                    // ----------
//                    // 保存処理
//                    // ----------
//                    ref = Database.database().reference()
//                ref.child("books/apple").observeSingleEvent(of: .value, with: { (snapshot) in
//                        // Get user value
//                        let value = snapshot.value as? NSDictionary
//                        let url = value?["url"] as? String ?? ""
//                        print(url)
//                    }) { (error) in
//                        print(error.localizedDescription)
//                    }
//                    let mdata = ["url": url.absoluteString,"title":"github"]
//                    ref.child("books").childByAutoId().setValue(mdata){
//                        (error:Error?, ref:DatabaseReference) in
//                        if let error = error {
//                            print("Data could not be saved: \(error).")
//                        } else {
//                            print("Data saved successfully!")
//                            // https://stackoverflow.com/questions/46057321/swift-3-photo-share-extension-with-firebase-database-not-working-after-first-sen
//                            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
//                        }
//                    }
//                    //let sharedDefaults: UserDefaults = UserDefaults(suiteName: self.suiteName)!
//                    //sharedDefaults.set(url.absoluteString!, forKey: self.keyName)  // そのページのURL保存
//                    //sharedDefaults.synchronize()
//                }
//
//            })
//        }
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        //self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

}
