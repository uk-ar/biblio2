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
    var handle: AuthStateDidChangeListenerHandle?
    var isbn: String?
    var url: String?
    override func viewDidLoad() {
        //https://stackoverflow.com/questions/46606221/share-extension-remove-textfield
        super.viewDidLoad()
        textView.isUserInteractionEnabled = false
        textView.textColor = UIColor(white: 0.5, alpha: 1)
        textView.tintColor = UIColor.clear // TODO hack to disable cursor
        let extensionItem = extensionContext?.inputItems.first as! NSExtensionItem
        let itemProvider = extensionItem.attachments?.first as! NSItemProvider
        //TODO: support Text,URL
        let propertyList = String(kUTTypePropertyList)
        if itemProvider.hasItemConformingToTypeIdentifier(propertyList) {
            itemProvider.loadItem(forTypeIdentifier: propertyList, options: nil, completionHandler: { (item, error) -> Void in
                guard let dictionary = item as? NSDictionary else { return }
                OperationQueue.main.addOperation {
                    if let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary{
                        self.url = results["URL"] as? String
                        self.isbn = results["isbn"] as? String
                        if let isbn = self.isbn {
                            self.textView.text = "ISBN: \(isbn)"
                        }else{
                            self.textView.text = "このページには対応していません"
                        }
                        //update validation
                        self.validateContent()
                    }
                }
            })
        } else {
            print("error")
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        // [START auth_listener]
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            // [START_EXCLUDE]
            if (user != nil){
                print("fireauth:current")
                return
            }
            print("fireauth:no current")
            Auth.auth()
                .signInAnonymously(){(authResult, error) in
                    guard let user = authResult?.user else{
                        return
                    }
                    Firestore.firestore().collection("users").document(user.uid).setData([
                        "isAnonymous": user.isAnonymous,
                        ])
            }
            // [END_EXCLUDE]
        }
        // [END auth_listener]
    }
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return isbn != nil
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // [START remove_auth_listener]
        Auth.auth().removeStateDidChangeListener(handle!)
        // [END remove_auth_listener]
    }
    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        // Use Firebase library to configure APIs

        let extensionItem: NSExtensionItem = self.extensionContext?.inputItems.first as! NSExtensionItem
        let itemProvider = extensionItem.attachments?.first as! NSItemProvider

        let user = Auth.auth().currentUser
        guard let uid = user?.uid else{
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        print("fireauth:user:",user)
        print("fireauth:uid:",uid)
        // ----------
        // 保存処理
        // ----------
        let db = Firestore.firestore()
        db.collection("posts").addDocument(data: [
            "author": db.collection("users").document(uid),
            "isbn": isbn ?? "",
            "url": url ?? ""
            ]){ err in
            if let err = err {
                print("fireauth:Error writing document: \(err)")
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            } else {
                print("fireauth:Document successfully written!")
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
    }

    override func configurationItems() -> [Any]! {
        return nil
    }
}
