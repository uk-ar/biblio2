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
    var handle: AuthStateDidChangeListenerHandle?
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
    func getUrl(callback: @escaping ((URL?) -> ())) {
        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let itemProvider = item.attachments?.first as? NSItemProvider,
            itemProvider.hasItemConformingToTypeIdentifier("public.url") {
            itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil) { (url, error) in
                if let shareURL = url as? URL {
                    callback(shareURL)
                }
            }
        }
        callback(nil)
    }
    override func viewDidLoad() {
        //https://stackoverflow.com/questions/46606221/share-extension-remove-textfield
        super.viewDidLoad()
        textView.isUserInteractionEnabled = false
        textView.textColor = UIColor(white: 0.5, alpha: 1)
        textView.tintColor = UIColor.clear // TODO hack to disable cursor
        textView.text = "foo"
        /*/getUrl { (url: URL?) in
            if let url = url {
                DispatchQueue.main.async {
                    // TODO this is also hacky
                    self.textView.text = "\(url)"
                    print("url:",url)
                }
            }
        }*/
        let extensionItem = extensionContext?.inputItems.first as! NSExtensionItem
        let itemProvider = extensionItem.attachments?.first as! NSItemProvider
        let propertyList = String(kUTTypePropertyList)
        if itemProvider.hasItemConformingToTypeIdentifier(propertyList) {
            itemProvider.loadItem(forTypeIdentifier: propertyList, options: nil, completionHandler: { (item, error) -> Void in
                guard let dictionary = item as? NSDictionary else { return }
                OperationQueue.main.addOperation {
                    if let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary,
                        let urlString = results["URL"] as? String,
                        //let isbn = results["isbn"] as? String,
                        let url = NSURL(string: urlString) {
                            print("URL retrieved: \(urlString)")
                            self.textView.text = "bar"
                            print("url:",urlString)
                        }
                }
            })
        } else {
            print("error")
        }
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
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        print("fireauth:user:",user)
        print("fireauth:uid:",uid)
        // shareExtension で NSURL を取得
        if !itemProvider.hasItemConformingToTypeIdentifier(puclicURL){
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        itemProvider.loadItem(forTypeIdentifier: puclicURL, options: nil, completionHandler: { (item, error) in
            // NSURLを取得する
            guard let url: NSURL = item as? NSURL else{
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                return
            }
            guard let regex = try? NSRegularExpression(pattern: "/\\d{9}[\\d|X]") else { self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                return
            }
            let uri = url.absoluteString!
            let results = regex.matches(in: uri, options: [], range:
                NSRange(uri.startIndex..<uri.endIndex,
                        in: uri))
            print("uri:",uri,results)
            for i in 0 ..< results.count {
                print("match:",results[i])
            }
            // ----------
            // 保存処理
            // ----------
            let db = Firestore.firestore()
            db.collection("posts").addDocument(data: [
                "author": db.collection("users").document(uid),
                "url": url.absoluteString ?? ""
                ]){ err in
                if let err = err {
                    print("fireauth:Error writing document: \(err)")
                } else {
                    print("fireauth:Document successfully written!")
                    self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                }
            }
        })
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        //self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        return nil
    }
}
