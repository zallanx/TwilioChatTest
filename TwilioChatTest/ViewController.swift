//
//  ViewController.swift
//  TwilioChatTest
//
//  Created by Allan Zhang on 4/6/17.
//  Copyright © 2017 Allan Zhang. All rights reserved.
//

import UIKit
import TwilioChatClient
import SwiftyJSON

class ViewController: UIViewController {
    
    
    var client: TwilioChatClient? = nil
    var generalChannel: TCHChannel? = nil
    var identity = ""
    var messages: [TCHMessage] = []
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet var textField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Temp: using PHP server to get identification TOKEN
        let deviceId = UIDevice.current.identifierForVendor!.uuidString
        let urlString = "http://localhost:8000/token.php?device=\(deviceId)"
        
        // Get JSON from server
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let url = URL(string: urlString)
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"
        
        let task = session.dataTask(with: request) { (data, response, error) in
            
            if let data = data {
                let json = JSON(data: data)
                let token = json["token"].stringValue
                self.identity = json["identity"].stringValue
                self.client = TwilioChatClient(token: token, properties: nil, delegate: self)
        
                DispatchQueue.main.async {
                    self.navigationItem.prompt = "Logged in as \"\(self.identity)\""
                }
            } else {
                print ("Error fetching token \(String(describing: error))")
            }
        }
        
        task.resume()
    
    }

    @IBAction func viewTapped(_ sender: AnyObject) {
        self.textField.resignFirstResponder()
    }
    
    // Scroll to bottom of table view for messages
    func scrollToBottomMessage() {
        if self.messages.count == 0 {
            return
        }
        let bottomMessageIndex = IndexPath(row: self.tableView.numberOfRows(inSection: 0) - 1,
                                           section: 0)
        self.tableView.scrollToRow(at: bottomMessageIndex, at: .bottom,
                                   animated: true)
    }


}

// MARK: Twilio Chat Delegate
extension ViewController: TwilioChatClientDelegate {
    func chatClient(_ client: TwilioChatClient!, synchronizationStatusChanged status: TCHClientSynchronizationStatus) {
        if status == .completed {
            // Join (or create) the general channel
            let defaultChannel = "general"
            client.channelsList().channel(withSidOrUniqueName: defaultChannel, completion: { (result, channel) in
                if let channel = channel {
                    self.generalChannel = channel
                    channel.join(completion: { result in
                        print("Channel joined with result \(String(describing: result))")
                        
                    })
                } else {
                    // Create the general channel (for public use) if it hasn't been created yet
                    client.channelsList().createChannel(options: [TCHChannelOptionFriendlyName: "General Chat Channel", TCHChannelOptionType: TCHChannelType.public.rawValue], completion: { (result, channel) -> Void in
                        if (result?.isSuccessful())! {
                            self.generalChannel = channel
                            self.generalChannel?.join(completion: { result in
                                self.generalChannel?.setUniqueName(defaultChannel, completion: { result in
                                    print("channel unique name set")
                                })
                            })
                        }
                    })
                }
            })
            
            
        }
    }
    
    // Called whenever a channel we've joined receives a new message
    func chatClient(_ client: TwilioChatClient!, channel: TCHChannel!, messageAdded message: TCHMessage!) {
        
        self.messages.append(message)
        self.tableView.reloadData()
        DispatchQueue.main.async {
            if self.messages.count > 0 {
                self.scrollToBottomMessage()
            }
        }
    }
}

// MARK: UITextField Delegate
extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let msg = self.generalChannel?.messages.createMessage(withBody: textField.text!)
        self.generalChannel?.messages.send(msg) { result in
            textField.text = ""
            textField.resignFirstResponder()
        }
        return true
    }
}

// MARK: UITableView Delegate
extension ViewController: UITableViewDelegate {
    
    // Return number of rows in the table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messages.count
    }
    
    // Create table view rows
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
            let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath)
            let message = self.messages[indexPath.row]
            
            // Set table cell values
            cell.detailTextLabel?.text = message.author
            cell.textLabel?.text = message.body
            cell.selectionStyle = .none
            return cell
    }
}

// MARK: UITableViewDataSource Delegate
extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
}


