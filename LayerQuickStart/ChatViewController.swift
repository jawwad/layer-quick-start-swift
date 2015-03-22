//
//  ChatViewController.swift
//  LayerQuickStart
//
//  Created by Jawwad Ahmad on 3/20/15.
//  Copyright (c) 2015 Layer. All rights reserved.
//

import UIKit

// Metadata keys related to navbar color
let LQSBackgroundColorMetadataKey          = "backgroundColor"
let LQSRedBackgroundColorMetadataKeyPath   = "backgroundColor.red"
let LQSBlueBackgroundColorMetadataKeyPath  = "backgroundColor.blue"
let LQSGreenBackgroundColorMetadataKeyPath = "backgroundColor.green"
let LQSRedBackgroundColor   = "red"
let LQSBlueBackgroundColor  = "blue"
let LQSGreenBackgroundColor = "green"

// Message State Images
let LQSMessageSentImageName      = "message-sent"
let LQSMessageDeliveredImageName = "message-delivered"
let LQSMessageReadImageName      = "message-read"

let LQSChatMessageCellReuseIdentifier = "ChatMessageCell"

let LQSLogoImageName = "Logo"
let LQSKeyboardHeight: CGFloat = 255.0

let LQSMaxCharacterLimit = 66

func LSRandomColor() -> UIColor {
    let redFloat   = CGFloat(arc4random_uniform(256)) / 255
    let greenFloat = CGFloat(arc4random_uniform(256)) / 255
    let blueFloat  = CGFloat(arc4random_uniform(256)) / 255
    return UIColor(red: redFloat, green: greenFloat, blue: blueFloat, alpha: 1.0)
}


class ChatViewController: UIViewController, UITextViewDelegate, LYRQueryControllerDelegate, UITableViewDataSource, UITableViewDelegate {

    var layerClient: LYRClient!

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var sendButton: UIButton!
    @IBOutlet private weak var inputTextView: UITextView!
    @IBOutlet private weak var typingIndicatorLabel: UILabel!

    private var conversation: LYRConversation!
    private var queryController: LYRQueryController!

    let LQSDateFormatter: NSDateFormatter = {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        return dateFormatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLayerNotificationObservers()
        fetchLayerConversation()

        // Setup for Shake
        becomeFirstResponder()

        let logoImageView = UIImageView(image: UIImage(named: LQSLogoImageName))
        logoImageView.frame = CGRectMake(0, 0, 36, 36)
        logoImageView.contentMode = .ScaleAspectFit
        navigationItem.titleView = logoImageView
        navigationItem.hidesBackButton = true

        inputTextView.delegate = self
        inputTextView.text = LQSInitialMessageText
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        scrollToBottom()
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func setupLayerNotificationObservers() {
        // Register for Layer object change notifications
        // For more information about Synchronization, check out https://developer.layer.com/docs/integration/ios#synchronization
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "didReceiveLayerObjectsDidChangeNotification:",
            name: LYRClientObjectsDidChangeNotification,
            object: nil)

        // Register for typing indicator notifications
        // For more information about Typing Indicators, check out https://developer.layer.com/docs/integration/ios#typing-indicator
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "didReceiveTypingIndicator:",
            name: LYRConversationDidReceiveTypingIndicatorNotification,
            object: conversation)

        // Register for synchronization notifications
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "didReceiveLayerClientWillBeginSynchronizationNotification:",
            name: LYRClientWillBeginSynchronizationNotification,
            object: layerClient)

        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "didReceiveLayerClientDidFinishSynchronizationNotification:",
            name: LYRClientDidFinishSynchronizationNotification,
            object: layerClient)
    }

    // MARK: - Fetching Layer Content

    func fetchLayerConversation() {
        // Fetches all conversations between the authenticated user and the supplied participant
        // For more information about Querying, check out https://developer.layer.com/docs/integration/ios#querying

        let query = LYRQuery(`class`: LYRConversation.self)
        query.predicate = LYRPredicate(property: "participants", `operator`: .IsEqualTo, value: [LQSCurrentUserID, LQSParticipantUserID, LQSParticipant2UserID])
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        var error: NSError?
        let conversations = layerClient.executeQuery(query, error: &error)
        if error == nil {
            println("\(conversations.count) conversations with participants \([LQSCurrentUserID, LQSParticipantUserID, LQSParticipant2UserID])")
        } else {
            println("Query failed with error \(error!.localizedDescription)")
        }

        // Retrieve the last conversation
        if conversations.count > 0 {
            conversation = conversations.lastObject as LYRConversation
            println("Get last conversation object: \(conversation.identifier)")
            // setup query controller with messages from last conversation
            setupQueryController()
        }
    }

    func setupQueryController() {
        // For more information about the Query Controller, check out https://developer.layer.com/docs/integration/ios#querying
        // Query for all the messages in conversation sorted by position
        let query = LYRQuery(`class`: LYRMessage.self)
        query.predicate = LYRPredicate(property: "conversation", `operator`: .IsEqualTo, value: conversation)
        query.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true)]

        // Set up query controller
        queryController = layerClient.queryControllerWithQuery(query)
        queryController.delegate = self

        var error: NSError?

        let success = queryController.execute(&error)
        if (success) {
            println("Query fetched \(queryController.numberOfObjectsInSection(0)) message objects")
        } else {
            println("Query failed with error: \(error!.localizedDescription)")
        }

        // Mark all conversations as read on launch
        conversation.markAllMessagesAsRead(nil)
    }

    // MARK: - Table View Data Source Methods

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return number of objects in queryController
        return Int(queryController.numberOfObjectsInSection(UInt(section)))
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // Set up custom ChatMessageCell for displaying message
        let cell = tableView.dequeueReusableCellWithIdentifier(LQSChatMessageCellReuseIdentifier, forIndexPath: indexPath) as ChatMessageCell
        return cell
    }

    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        // Get Message Object from queryController
        let message = queryController.objectAtIndexPath(indexPath) as LYRMessage

        // Set Message Text
        let messagePart = message.parts[0] as LYRMessagePart
        let cell = cell as ChatMessageCell
        cell.messageLabel.text = NSString(data: messagePart.data, encoding: NSUTF8StringEncoding)

        var timestampText = ""

        // If the message was sent by current user, show Receipent Status Indicators
        if message.sentByUserID == LQSCurrentUserID {
            switch message.recipientStatusForUserID(LQSParticipantUserID) {
            case .Sent:
                cell.messageStatus.image = UIImage(named:LQSMessageSentImageName)
                timestampText = "Sent: \(LQSDateFormatter.stringFromDate(message.sentAt))"
            case .Delivered:
                cell.messageStatus.image = UIImage(named: LQSMessageDeliveredImageName)
                timestampText = "Delivered: \(LQSDateFormatter.stringFromDate(message.sentAt))"
            case .Read:
                cell.messageStatus.image = UIImage(named: LQSMessageReadImageName)
                timestampText = "Read: \(LQSDateFormatter.stringFromDate(message.receivedAt))"
            case .Invalid:
                println("Participant: Invalid")
            }
        } else {
            timestampText = "Sent: \(LQSDateFormatter.stringFromDate(message.sentAt))"
        }

        cell.deviceLabel.text = "\(message.sentByUserID) @ \(timestampText)"
    }

    // MARK: - Receiving Typing Indicator

    @objc private func didReceiveTypingIndicator(notification: NSNotification) {
        // For more information about Typing Indicators, check out https://developer.layer.com/docs/integration/ios#typing-indicator

        let participantID = notification.userInfo![LYRTypingIndicatorParticipantUserInfoKey] as String
        let typingIndicator = notification.userInfo![LYRTypingIndicatorValueUserInfoKey]!.unsignedIntegerValue

        if Int(typingIndicator) == Int(LYRTypingIndicator.DidBegin.rawValue) {
            typingIndicatorLabel.alpha = 1
            typingIndicatorLabel.text = "\(participantID), is, typing..."
        } else {
            typingIndicatorLabel.alpha = 0
            typingIndicatorLabel.text = ""
        }
    }

    // MARK: - IBActions

    @IBAction private func sendMessageAction(sender: AnyObject) {
        // Send Message
        sendMessage(inputTextView.text)

        // Lower the keyboard
        moveViewUpToShowKeyboard(false)
        inputTextView.resignFirstResponder()
    }

    private func sendMessage(messageText: String) {
        // Send a Message
        // See "Quick Start - Send a Message" for more details
        // https://developer.layer.com/docs/quick-start/ios#send-a-message

        // If no conversations exist, create a new conversation object with a single participant
        if conversation == nil {
            var error: NSError?
            conversation = layerClient.newConversationWithParticipants(NSSet(array: [LQSParticipantUserID, LQSParticipant2UserID]), options: nil, error:&error)
            if conversation == nil {
                println("New Conversation creation failed: \(error!.localizedDescription)")
            }
        }

        // Creates a message part with text/plain MIME Type
        let messagePart = LYRMessagePart(text: messageText)

        // Creates and returns a new message object with the given conversation and array of message parts
        let pushMessage = "\(layerClient.authenticatedUserID), says, \(messageText)"
        let message = layerClient.newMessageWithParts([messagePart], options: [LYRMessageOptionsPushNotificationAlertKey: pushMessage], error: nil)

        // Sends the specified message
        var error: NSError?
        let success = conversation.sendMessage(message, error: &error)
        if success {
            // If the message was sent by the participant, show the sentAt time and mark the message as read
            println("Message queued to be sent: \(messageText)")
            inputTextView.text = ""
        } else {
            println("Message send failed: \(error!.localizedDescription)")
        }
    }

    // MARK: - Set up for Shake

    override func canBecomeFirstResponder() -> Bool {
        return true
    }

    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent) {
        // If user shakes the phone, change the navbar color and set metadata
        if motion == .MotionShake {
            let newNavBarBackgroundColor = LSRandomColor()
            navigationController?.navigationBar.barTintColor = newNavBarBackgroundColor

            var redFloat: CGFloat = 0.0, greenFloat: CGFloat = 0.0, blueFloat: CGFloat = 0.0, alpha: CGFloat = 0.0
            newNavBarBackgroundColor.getRed(&redFloat, green: &greenFloat, blue: &blueFloat, alpha: &alpha)


            // For more information about Metadata, check out https://developer.layer.com/docs/integration/ios#metadata
            let metadata = [
                LQSBackgroundColorMetadataKey: [
                    LQSRedBackgroundColor   : "\(redFloat)",
                    LQSGreenBackgroundColor : "\(greenFloat)",
                    LQSBlueBackgroundColor  : "\(blueFloat)",
                ]
            ]
            conversation.setValuesForMetadataKeyPathsWithDictionary(metadata, merge: true)
        }
    }

    // MARK: - UITextView Delegate Methods

    func textViewDidBeginEditing(textView: UITextView) {
        // For more information about Typing Indicators, check out https://developer.layer.com/docs/integration/ios#typing-indicator
        // Sends a typing indicator event to the given conversation.
        conversation.sendTypingIndicator(.DidBegin)
        moveViewUpToShowKeyboard(true)
    }

    func textViewDidEndEditing(textView: UITextView) {
        // Sends a typing indicator event to the given conversation.
        conversation.sendTypingIndicator(.DidFinish)
    }

    // Move up the view when the keyboard is shown
    func moveViewUpToShowKeyboard(movedUp: Bool) {
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(0.3)

        var rect = view.frame
        if movedUp {
            if rect.origin.y == 0 {
                rect.origin.y = view.frame.origin.y - LQSKeyboardHeight
            }
        } else {
            if rect.origin.y < 0 {
                rect.origin.y = view.frame.origin.y + LQSKeyboardHeight
            }
        }
        view.frame = rect
        UIView.commitAnimations()
    }

    // If the user hits Return then dismiss the keyboard and move the view back down

    func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            inputTextView.resignFirstResponder()
            moveViewUpToShowKeyboard(false)
            return false
        }

        let limit = LQSMaxCharacterLimit
        return !(inputTextView.text.utf16Count > limit && text.utf16Count > range.length)
    }

    // MARK: - Query Controller Delegate Methods

    func queryControllerWillChangeContent(queryController: LYRQueryController) {
        tableView.beginUpdates()
    }


    func queryController(controller: LYRQueryController!, didChangeObject object: AnyObject!, atIndexPath indexPath: NSIndexPath!, forChangeType type: LYRQueryControllerChangeType, newIndexPath: NSIndexPath!) {
        // Automatically update tableview when there are change events

        switch type {
        case .Insert:
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
        case .Update:
            tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
        case .Delete:
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        }
    }

    func queryControllerDidChangeContent(queryController: LYRQueryController!) {
        tableView.endUpdates()
        scrollToBottom()
    }

    // MARK: - Layer Sync Notification Handler

    @objc private func didReceiveLayerClientWillBeginSynchronizationNotification(notification: NSNotification) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }

    @objc private func didReceiveLayerClientDidFinishSynchronizationNotification(notification: NSNotification) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }

    // MARK: - Layer Object Change Notification Handler

    @objc private func didReceiveLayerObjectsDidChangeNotification(notification: NSNotification) {
        // For more information about Synchronization, check out https://developer.layer.com/docs/integration/ios#synchronization
        if conversation == nil {
            fetchLayerConversation()
            tableView.reloadData()
        }
        // Get nav bar colors from conversation metadata
        setNavbarColorFromConversationMetadata(conversation.metadata)
    }

    // MARK: - General Helper Methods

    func scrollToBottom() {
        if conversation != nil {
            let ip = NSIndexPath(forRow: tableView.numberOfRowsInSection(0) - 1, inSection: 0)
            tableView.scrollToRowAtIndexPath(ip, atScrollPosition: .Top, animated: true)
        }
    }

    func setNavbarColorFromConversationMetadata(metadata: NSDictionary) {
        // For more information about Metadata, check out https://developer.layer.com/docs/integration/ios#metadata
        if metadata[LQSBackgroundColorMetadataKey] == nil {
            return
        }

        let redColor = CGFloat(metadata.valueForKeyPath(LQSRedBackgroundColorMetadataKeyPath)!.floatValue)
        let blueColor = CGFloat(metadata.valueForKeyPath(LQSBlueBackgroundColorMetadataKeyPath)!.floatValue)
        let greenColor = CGFloat(metadata.valueForKeyPath(LQSGreenBackgroundColorMetadataKeyPath)!.floatValue)
        navigationController?.navigationBar.barTintColor = UIColor(red: redColor, green: greenColor, blue: blueColor, alpha: 1.0)
    }
    
}
