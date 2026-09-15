  // TBT inline replies run without presenting a Flutter screen.
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void) {
    guard response.actionIdentifier == "tbt_reply",
          let reply = response as? UNTextInputNotificationResponse else {
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
      return
    }
    let original = response.notification.request.content
    var data = original.userInfo
    if let payload = data["payload"] as? String, let bytes = payload.data(using: .utf8),
       let decoded = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] {
      data = decoded
    }
    guard let recipient = data["recipientId"] as? String,
          let thread = data["sourceId"] as? String,
          let notification = data["notificationId"] as? String,
          ["message", "group_message"].contains(data["type"] as? String ?? ""),
          !reply.userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      completionHandler(); return
    }
    let text = reply.userText.trimmingCharacters(in: .whitespacesAndNewlines)
    let finish: (Bool) -> Void = { success in
      let content = UNMutableNotificationContent()
      content.title = original.title
      content.body = success ? "Yanıt gönderildi" : "Yanıt doğrulanamadı. Aynı metinle tekrar dene veya sohbeti aç. Taslak: \(text)"
      content.userInfo = data
      content.threadIdentifier = thread
      content.categoryIdentifier = success ? "" : "TBT_CHAT"
      // Replace only the originating notification; never remove newer messages.
      center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
      center.add(UNNotificationRequest(identifier: response.notification.request.identifier, content: content, trigger: nil)) { _ in completionHandler() }
    }
    tbtAuthenticatedReply(recipient: recipient, remaining: 20) { user in
      guard let user = user else { finish(false); return }
      user.getIDToken { token, error in
        guard let token = token, error == nil else { finish(false); return }
        let project = FirebaseApp.app()?.options.projectID ?? ""
        guard !project.isEmpty, let url = URL(string: "https://europe-west1-\(project).cloudfunctions.net/replyToNotification") else { finish(false); return }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["data": ["threadId": thread, "notificationId": notification, "text": text]])
        URLSession.shared.dataTask(with: request) { bytes, response, error in
          let status = (response as? HTTPURLResponse)?.statusCode ?? 0
          let json = bytes.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
          finish(error == nil && status == 200 && json?["result"] != nil && json?["error"] == nil)
        }.resume()
      }
    }
  }

  private func tbtAuthenticatedReply(recipient: String, remaining: Int, completion: @escaping (User?) -> Void) {
    if FirebaseApp.app() != nil, let user = Auth.auth().currentUser {
      completion(user.uid == recipient ? user : nil); return
    }
    guard remaining > 0 else { completion(nil); return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      self.tbtAuthenticatedReply(recipient: recipient, remaining: remaining - 1, completion: completion)
    }
  }
