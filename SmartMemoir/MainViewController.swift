//
//  MainViewController.swift
//  SmartMemoir
//
//  Created by Hanker Lu on 2024/8/28.
//

import UIKit
import Speech

class RemotePhotoService {
    private let baseURL = "http://119.45.18.3:789"
    private let imagePath = "/photograph/image/"
    
    /// 获取远程照片的URL
    /// - Parameter photoID: 照片ID
    /// - Returns: 完整的照片URL
    func getPhotoURL(photoID: String) -> URL? {
        return URL(string: baseURL + imagePath + photoID)
    }
    
    /// 下载远程照片
    /// - Parameters:
    ///   - photoID: 照片ID
    ///   - completion: 完成回调，返回下载的图片或错误
    func downloadPhoto(photoID: String, completion: @escaping (UIImage?, Error?) -> Void) {
        guard let url = getPhotoURL(photoID: photoID) else {
            completion(nil, NSError(domain: "无效的URL", code: 0, userInfo: nil))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            print("下载照片成功")
            if let data = data {
                print("返回的完整数据: \(String(data: data, encoding: .utf8) ?? "无法解码数据")")
            } else {
                print("返回的数据为空")
            }
                
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "无效的图片数据", code: 0, userInfo: nil))
                }
                return
            }
            
            // 将返回的数据解析为字符串
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let responseData = jsonObject["data"] as? [String: Any],
                   let base64String = responseData["imageData"] as? String,
                   let imageData = Data(base64Encoded: base64String),
                   let image = UIImage(data: imageData) {
                    DispatchQueue.main.async {
                        completion(image, nil)
                    }
                } else {
                    print("无法解析JSON数据或提取图像数据")
                    DispatchQueue.main.async {
                        completion(nil, NSError(domain: "数据解析失败", code: 0, userInfo: nil))
                    }
                }
            } catch {
                print("JSON解析错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }.resume()
    }

    /// 获取指定用户的照片
    /// - Parameters:
    ///   - userID: 用户ID
    ///   - completion: 完成回调，返回下载的图片或错误
    func getUserPhoto(userID: String, completion: @escaping (UIImage?, Error?) -> Void) {
        let urlString = "\(baseURL)/photograph/image/user/\(userID)"
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "无效的URL", code: 0, userInfo: nil))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                completion(nil, NSError(domain: "无效的图片数据", code: 0, userInfo: nil))
                return
            }
            
            completion(image, nil)
        }.resume()
    }
    
    /// 上传照片到远程服务器
    /// - Parameters:
    ///   - image: 要上传的图片
    ///   - completion: 完成回调，返回上传成功的照片ID或错误
    func uploadPhoto(_ image: UIImage, completion: @escaping (String?, Error?) -> Void) {
        guard let url = URL(string: baseURL + "/upload") else {
            completion(nil, NSError(domain: "无效的上传URL", code: 0, userInfo: nil))
            return
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil, NSError(domain: "图片转换失败", code: 0, userInfo: nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.uploadTask(with: request, from: imageData) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data,
                  let responseString = String(data: data, encoding: .utf8),
                  let photoID = responseString.components(separatedBy: "/").last else {
                completion(nil, NSError(domain: "无效的服务器响应", code: 0, userInfo: nil))
                return
            }
            
            completion(photoID, nil)
        }
        
        task.resume()
    }
}

class MainViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate, URLSessionDataDelegate {

    @IBOutlet weak var mainImageView: UIImageView!
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var switchButton: UIButton!
    @IBOutlet weak var debugListButton: UIButton!
    @IBOutlet weak var speechButton: UIButton!
    @IBOutlet weak var sendAIButton: UIButton!
    @IBOutlet weak var randomPhotoButton: UIButton!
    
    @IBAction func selectButtonTapped(_ sender: UIButton) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }

    @IBAction func debugListButtonTapped(_ sender: UIButton) {
        searchAllPhoto()
        print("--------图片和数据库调试内容分割线---------")
        loadPhotoDatabase()
    }

    @IBAction func rebuildListButtonTapped(_ sender: UIButton) {
        clearPhotoDatabase()
        rebuildPhotoDatabase()
    }

    @IBAction func speechButtonTapped(_ sender: UIButton) {
        print("语音识别按钮被点击")
        DispatchQueue.global(qos: .userInitiated).async {
            print("开始语音识别, 创建语音识别任务")
            self.startSpeechRecognition()
        }
    }
    

    //待在真机上验证
    private func startSpeechRecognition() {
        guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) else {
            print("语音识别器不可用")
            return
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        // 创建语音识别任务
        let recognitionTask = speechRecognizer.recognitionTask(with: request) { (result, error) in
            if let result = result {
                let spokenText = result.bestTranscription.formattedString
                print("识别的文本: \(spokenText)")
            }
            if let error = error {
                print("语音识别发生错误: \(error.localizedDescription)")
            }
        }
        
        // 开始录音
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        
        // 设置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("设置音频会话失败: \(error.localizedDescription)")
            return
        }
        
        // 设置录音格式
        let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("音频引擎启动失败: \(error.localizedDescription)")
            recognitionTask.cancel()
        }
    }

    @IBOutlet weak var autoMatchPhotoButton: UIButton!
    @IBAction func autoMatchPhotoButtonTapped(_ sender: UIButton) {
        let alertController = UIAlertController(title: "输入内容", message: "请输入要匹配的内容", preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "输入内容"
        }
        let confirmAction = UIAlertAction(title: "确认", style: .default) { [weak self] (_) in
            guard let textField = alertController.textFields?.first, let text = textField.text else { return }
            self?.autoMatchPhotoWithLanguage(userInput: text)
        }
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
        // autoMatchPhotoWithLanguage(userInput: ""))
    }
    
    // 根据用户输入，自动匹配照片
    func autoMatchPhotoWithLanguage(userInput: String) {
        var photoDetails: [(String, String)] = []
        for (key, tags) in photoDatabase {
            let nonPathTags = tags.filter { !$0.hasPrefix("路径:") }.joined(separator: ", ")
            photoDetails.append((key, nonPathTags))
        }
        let content = "这是用户输入的文本：" + userInput + "。请根据这个文本，从以下照片信息中找到与文本最匹配的照片，并返回照片的文件名。（请你最终只返回一个文件名，不要返回任何其他文字）" + photoDetails.map { "照片文件名: \($0.0), 照片描述: \($0.1)" }.joined(separator: "\n")
        print("[autoMatchPhotoWithLanguage]----------content:", content)
        sentZhipuAIMessageByCustomStream(content: content)
        
        // 等待completeDataStreamStatus为2后，调用displayPhotoByAIResult
        DispatchQueue.global().async {
            while self.completeDataStreamStatus != 2 {
                usleep(100000) //  每0.1秒检查一次
            }
            DispatchQueue.main.async {
                self.displayPhotoByAIResult(aiResult: self.completeDataStream)
            }
        }
    }

    func displayPhotoByAIResult(aiResult: String) 
    {
        let photoFileName = aiResult
        let photoURL = photoDatabase[photoFileName]?.first
        if photoURL != nil && photoURL!.hasPrefix("路径:") {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            // let fileURL = documentsDirectory.appendingPathComponent(photoURL!.replacingOccurrences(of: "路径:", with: ""))

            let fileURL = documentsDirectory.appendingPathComponent(aiResult)
            do {
                let imageData = try Data(contentsOf: fileURL)
                let image = UIImage(data: imageData)!
                mainImageView.image = image
                print("已显示照片: \(photoFileName)")
            } catch {
                print("显示照片时出错: \(error)")
            }
        }
        else {
            print("没有匹配到照片")
        }
        completeDataStreamStatus = 0
    }
    
    func sentZhipuAIMessageByCustomStream(content: String) {
        completeDataStream = ""
        sendZhipuAiRequestStream(messages: [["role": "user", "content": content]]) { result in
            switch result {
            case .success(_):
                print("智谱AI请求成功(流式传输): ")
            case .failure(let error):
                print("智谱AI请求错误(流式传输): \(error)")
                // 在这里处理请求错误
            }
        }
    }

    @IBAction func zhipuAIButtonTapped(_ sender: UIButton) {
        // sentZhipuAIMessageWithContent()
        sentZhipuAIMessageWithContentStream()
    }

    // 处理流式响应的函数
    func sentZhipuAIMessageWithContentStream() {
        var final_content = ""
        do {
            _ = try JSONSerialization.data(withJSONObject: photoDatabase, options: [])
            
            // let photoDatabaseInfoString = String(data: photoDatabaseInfo, encoding: .utf8) ?? ""
            // print("----------photoDatabaseInfoString:", photoDatabaseInfoString)
            // let photoDatabaseInfoString = extractTagsFromPhotoDatabase()
            // print("----------photoDatabaseInfoString:", photoDatabaseInfoString)
            let photoDatabaseInfoString = extractPhotoPathsFromCurrentImageViewPhoto()
            print("----------photoDatabaseInfoString:", photoDatabaseInfoString)
            final_content = "你好，这是关于一张照片的信息描述的数据库文件：" + photoDatabaseInfoString + "。\n你能试着帮我简单解读和描述这些信息吗？（注意：请你用日常口语聊天的方式来描述，不要用专业术语）"
        } catch {
            print("转换JSON数据时出错: \(error)")
            final_content = "你好"
        }
        
        sendZhipuAiRequestStream(messages: [["role": "user", "content": final_content]]) { result in
            switch result {
            case .success(_):
                print("智谱AI请求成功(流式传输): ")
            case .failure(let error):
                print("智谱AI请求错误(流式传输): \(error)")
                // 在这里处理请求错误
            }
        }
    }

    // 发送请求到智谱AI的函数，适应流式块传输接收
    func sendZhipuAiRequestStream(messages: [[String: String]], completion: @escaping (Result<String, Error>) -> Void) {
        // 定义API的URL字符串
        let urlString = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        // 尝试创建URL对象，如果失败则返回错误
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "无效的URL", code: 0, userInfo: nil)))
            return
        }
        
        // 创建URLRequest对象
        var request = URLRequest(url: url)
        // 设置HTTP方法为POST
        request.httpMethod = "POST"
        // 设置请求头，指定内容类型为JSON
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 定义请求参数
        let parameters: [String: Any] = [
            "model": "glm-4",
            "messages": messages,
            "stream": true,
            "temperature": 0.95,
            "top_p": 0.7
        ]

        do {
            request.allHTTPHeaderFields = [
            "Authorization": "5970c032a7158d0f72d69890e806c912.KOAJqVp6cvhp7LS3",
            "Content-Type": "application/json"
            ]
            // 尝试将参数转换为JSON数据
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            // 如果转换失败，返回错误
            completion(.failure(error))
            return
        }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        completeDataStreamStatus = 0
        task.resume()
    }

    var completeDataStream = ""
    var completeDataStreamStatus = 0
        // URLSessionDataDelegate 方法
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let string = String(data: data, encoding: .utf8) {
            let lines = string.components(separatedBy: "\n")
            for line in lines {
                if line.hasPrefix("data: ") {
                    let content = String(line.dropFirst(6))
                    if content == "[DONE]" {
                        // print("\n流式响应结束")
                        print("\n完整的数据流: \(completeDataStream)")
                        completeDataStreamStatus = 2
                        // 在这里处理响应结束的逻辑
                    } else {
                        // 尝试解析 JSON 内容
                        do {
                            if let jsonData = content.data(using: .utf8),
                               let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let firstChoice = choices.first,
                               let delta = firstChoice["delta"] as? [String: String],
                               let text = delta["content"] {
                                print(text, terminator: "")
                                // 在这里处理接收到的内容片段
                                // 将内容片段拼接到完整的数据流中
                                completeDataStream.append(text)
                                completeDataStreamStatus = 1
                            }
                        } catch {
                            print("解析 JSON 时出错：\(error)")
                        }
                    }
                }
            }
        }
    }

    // 发送智谱AI消息并获取回调
    func sentZhipuAIMessageWithContent() {
        var final_content = ""
        do {
            let photoDatabaseInfo = try JSONSerialization.data(withJSONObject: photoDatabase, options: [])
            
            let photoDatabaseInfoString = String(data: photoDatabaseInfo, encoding: .utf8) ?? ""
            print("----------photoDatabaseInfoString:", photoDatabaseInfoString)
            final_content = "你好，这是一份关于照片文件及文件对应的信息描述的数据库文件：" + photoDatabaseInfoString + "。你能试着帮我解读每一张照片背后的信息吗？"
        } catch {
            print("转换JSON数据时出错: \(error)")
            final_content = "你好"
        }
        
        sendZhipuAiRequest(messages: [["role": "user", "content": final_content]]) { result in
            switch result {
            case .success(let content):
                print("智谱AI返回内容: \(content)")
                // 在这里处理成功返回的内容
            case .failure(let error):
                print("智谱AI请求错误: \(error)")
                // 在这里处理请求错误
            }
        }
    }

    // 发送请求到智谱AI的函数
    func sendZhipuAiRequest(messages: [[String: String]], completion: @escaping (Result<String, Error>) -> Void) {
        // 定义API的URL字符串
        let urlString = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        // 尝试创建URL对象，如果失败则返回错误
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "无效的URL", code: 0, userInfo: nil)))
            return
        }
        
        // 创建URLRequest对象
        var request = URLRequest(url: url)
        // 设置HTTP方法为POST
        request.httpMethod = "POST"
        // 设置请求头，指定内容类型为JSON
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 定义请求参数
        let parameters: [String: Any] = [
            "model": "glm-4",
            "messages": messages,
            "stream": false,
            "temperature": 0.95,
            "top_p": 0.7
        ]

        do {
            request.allHTTPHeaderFields = [
            "Authorization": "5970c032a7158d0f72d69890e806c912.KOAJqVp6cvhp7LS3",
            "Content-Type": "application/json"
            ]
            // 尝试将参数转换为JSON数据
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            // 如果转换失败，返回错误
            completion(.failure(error))
            return
        }
        
        // 创建并执行网络请求任务
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // 如果有错误，返回错误
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // 确保返回的数据不为空
            guard let data = data else {
                completion(.failure(NSError(domain: "没有数据返回", code: 0, userInfo: nil)))
                return
            }

            print("非流式传输")
            do {               
                // print("原始返回的报文内容: \(String(data: data, encoding: .utf8) ?? "无法解析")")
                // 尝试解析返回的JSON数据
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let firstChoice = choices.first,
                let message = firstChoice["message"] as? [String: Any],
                let content = message["content"] as? String {
                    // 如果成功解析，返回内容
                    // print("成功解析返回内容: \(content)") // 增加打印返回内容
                    print("成功解析返回内容")
                    completion(.success(content))
                } else {
                    // 如果解析失败，返回错误
                    print("返回内容解析失败")   
                    completion(.failure(NSError(domain: "无法解析响应", code: 0, userInfo: nil)))
                }
            } catch {
                // 如果解析过程中出现错误，返回错误
                print("返回内容解析错误")
                completion(.failure(error))
            }
        }
        
        
        // 开始网络请求任务
        task.resume()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
       if let selectedImage = info[.originalImage] as? UIImage {
           mainImageView.image = selectedImage
           
            // 获取文档目录路径
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                // 创建文件名
                let fileName = UUID().uuidString + ".png"
                let fileURL = documentsDirectory.appendingPathComponent(fileName)
                
                // 将图片转换为PNG数据并写入文件
                if let data = selectedImage.pngData() {
                    do {
                        try data.write(to: fileURL)
                        print("图片已保存到: \(fileURL)")

                        let currentTime = Date() // 获取当前时间
                        let photoURL = fileName // 获取照片文件名
                        let tags: [String] = ["路径: \(photoURL)", "保存时间: \(currentTime)"] // 保存照片地址和当前时间
                        addPhoto(withName: fileName, tags: tags)
                        savePhotoDatabase()
                        currentPhotoFileName = fileName
                        // print("选择的图片已保存内部数据库: \(fileName)")

                    } catch {
                        print("保存图片时出错: \(error)")
                    }
                }
            }
       }
       dismiss(animated: true, completion: nil)
   }
   
   func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
       dismiss(animated: true, completion: nil)
   }

    

    var photoDatabase: [String: [String]] = [:] // 存储照片的数据库，键为图片名称，值为标签数组

    // 添加照片和标签
    func addPhoto(withName name: String, tags: [String]) {
        photoDatabase[name] = tags
    }

    // 通过标签检索照片
    func searchPhotos(byTag tag: String) -> [String] {
        return photoDatabase.filter { $0.value.contains(tag) }.map { $0.key }
    }

    // 为某张图片添加标签
    func addTags(toPhoto name: String, newTags: [String]) {
        if var tags = photoDatabase[name] {
            tags.append(contentsOf: newTags)
            photoDatabase[name] = tags
        }
    }

    var currentPhotoFileName: String?
    @IBAction func randomPhotoButtonTapped(_ sender: UIButton) {
        loadRandomPhoto()
    }

    func loadRandomPhoto() {
        // 检查photoDatabase是否为空
        if photoDatabase.isEmpty {
            print("照片数据库为空，无法加载照片。")
            return
        }
        
        // 从photoDatabase中随机选择一张照片
        let randomIndex = Int.random(in: 0..<photoDatabase.count)
        print("随机索引: \(randomIndex), 随机照片数量: \(photoDatabase.count)")
        
        let randomPhotoKey = Array(photoDatabase.keys)[randomIndex]
        currentPhotoFileName = randomPhotoKey
        
        // 获取照片的URL
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photoURL = documentsDirectory.appendingPathComponent(randomPhotoKey)
        
        // 加载照片到mainImageView中
        do {
            let imageData = try Data(contentsOf: photoURL)
            let image = UIImage(data: imageData)!
            mainImageView.image = image
            print("已加载照片: \(randomPhotoKey)")
        } catch {
            print("加载照片时出错: \(error)")
        }
    }

    func savePhotoDatabase() {
        // 获取文档目录路径
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent("photoDatabase.json")
            do {
                // 将photoDatabase转换为JSON数据
                let jsonData = try JSONSerialization.data(withJSONObject: photoDatabase, options: .prettyPrinted)
                // 将JSON数据写入文件
                try jsonData.write(to: fileURL)
                print("照片数据库已保存到: \(fileURL)")
            } catch {
                print("保存照片数据库时出错: \(error)")
            }
        }
    }

    //特殊调试按键：一键清空数据库
    func clearPhotoDatabase() {
        photoDatabase.removeAll()
        savePhotoDatabase()
        print("照片数据库已清空")
    }

    func rebuildPhotoDatabase() {
        // 获取文档目录路径
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                // 获取文档目录下的所有文件
                let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
                
                // 遍历文件URLs以重建数据库
                for url in fileURLs {
                    let fileName = url.lastPathComponent
                    let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff"]
                    if imageExtensions.contains(fileName.split(separator: ".").last?.lowercased() ?? "") {
                        let currentTime = Date() // 获取当前时间
                        let photoURL = fileName // 获取照片文件名
                        let tags: [String] = ["路径: \(photoURL)", "保存时间: \(currentTime)"] // 保存照片地址和当前时间
                        addPhoto(withName: fileName, tags: tags)
                    }
                }
                savePhotoDatabase()
                print("照片数据库已重新建立")
            } catch {
                print("重建照片数据库时出错: \(error.localizedDescription)")
            }
        }
    }

    func loadPhotoDatabase() {
        // 获取文档目录路径
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent("photoDatabase.json")
            do {
                // 读取JSON数据
                let jsonData = try Data(contentsOf: fileURL)
                // 将JSON数据转换为字典
                if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: [String]] {
                    photoDatabase = json
                    print("照片数据库已加载: \(photoDatabase)")
                }
            } catch {
                print("加载照片数据库时出错: \(error)")
            }
        }
    }

    @IBOutlet weak var addTagToCurrentPhotoButton: UIButton!
    @IBAction func addTagToCurrentPhotoButtonTapped(_ sender: UIButton) {
        let alertController = UIAlertController(title: "添加标签", message: "请输入标签内容", preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "标签内容"
        }
        let confirmAction = UIAlertAction(title: "确认", style: .default) { [weak self] (_) in
            guard let textField = alertController.textFields?.first, let text = textField.text else { return }
            self?.addTagToCurrentPhoto(tag: text)
        }
        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
        // addTagToCurrentPhoto(tag: text)
    }

    func addTagToCurrentPhoto(tag: String) {
        if let currentPhotoFileName = currentPhotoFileName {
            if var tags = photoDatabase[currentPhotoFileName] {
                tags.append(tag)
                photoDatabase[currentPhotoFileName] = tags
                print("已为照片 \(currentPhotoFileName) 添加标签: \(tag)")
                savePhotoDatabase()
            } else {
                print("照片 \(currentPhotoFileName) 的标签添加失败")
            }
        }
    }

    func extractTagsFromPhotoDatabase() -> String {
        var allTags: [String] = []
        for (_, tags) in photoDatabase {
            for tag in tags {
                if !tag.hasPrefix("路径:") {
                    allTags.append(tag)
                }
            }
        }
        return allTags.joined(separator: ", ")
    }

    func extractPhotoPathsFromCurrentImageViewPhoto  () -> String {
        var allTags: [String] = []
        if let currentPhotoFileName = currentPhotoFileName {
            if let tags = photoDatabase[currentPhotoFileName] {
                for tag in tags {
                    if !tag.hasPrefix("路径:") {
                        allTags.append(tag)
                    }
                }
            }
        }
        return allTags.joined(separator: ", ")
    }

    
    func searchAllPhoto() {
        // 获取文档目录路径
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                // 获取文档目录下的所有文件
                let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
                
                // 遍历文件URLs以获取已存储的照片
                for url in fileURLs {
                    // 处理每个文件的逻辑，这里可以是加载到界面上或者其他操作
                    print("已存储的照片文件: \(url.lastPathComponent)")
                }
            } catch {
                print("Error while enumerating files \(documentsDirectory.path): \(error.localizedDescription)")
            }
        }
    }

    @IBAction func uploadPhotoToRemoteServer(_ sender: UIButton) {
        guard let image = mainImageView.image else {
            print("没有图片可上传")
            return
        }
        
        let remotePhotoService = RemotePhotoService()
        remotePhotoService.uploadPhoto(image) { [weak self] (photoID, error) in
            if let error = error {
                print("上传照片时出错: \(error)")
            } else if let photoID = photoID {
                print("照片已成功上传，ID为: \(photoID)")
                // 更新UI或执行其他操作
            }
        }
    }


    @IBOutlet weak var downloadPhotoButton: UIButton!
    @IBAction func downloadPhotoFromRemoteServer(_ sender: UIButton) {
        let photoID = "1a18c4d86d29bbd489ece231fb79cbec"
        guard !photoID.isEmpty else {
            print("没有照片ID可下载")
            return
        }
        
        let remotePhotoService = RemotePhotoService()
        remotePhotoService.downloadPhoto(photoID: photoID) { [weak self] (image, error) in
            if let error = error {
                print("下载照片时出错: \(error)")
            } else if let image = image {
                self?.mainImageView.image = image
                print("照片已成功下载并显示")
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPhotoDatabase()

        // Do any additional setup after loading the view.
    }



    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

/// 管理长期激励系统的类
class LongTermIncentiveManager {
    private var incentives: [String: Int] = [:] // 存储每个标签的激励点数

    /// 为指定标签添加激励点数
    /// - Parameters:
    ///   - tag: 标签名称
    ///   - points: 激励点数
    func addIncentive(forTag tag: String, points: Int) {
        incentives[tag, default: 0] += points
        print("为标签 '\(tag)' 添加了 \(points) 点激励。当前总激励: \(incentives[tag]!)")
    }

    /// 获取指定标签的激励点数
    /// - Parameter tag: 标签名称
    /// - Returns: 激励点数
    func getIncentive(forTag tag: String) -> Int {
        return incentives[tag, default: 0]
    }

    /// 显示所有标签的激励点数
    func displayAllIncentives() {
        for (tag, points) in incentives {
            print("标签: '\(tag)', 激励点数: \(points)")
        }
    }
}

/// 负责通过SSH将照片传输到局域网内远程嵌入式系统的类
class PhotoSSHTransfer {
    private let sshSession: Any?
    
    init(host: String, port: Int, username: String, password: String) {
        // 注意:这里需要导入适当的SSH库并正确初始化SSH会话
        // 以下代码仅作为示例,实际使用时需要替换为真实的SSH库实现
        self.sshSession = nil
        print("SSH会话初始化 - 主机: \(host), 端口: \(port), 用户名: \(username)")
    }
    
    /// 传输单张照片到远程系统
    /// - Parameters:
    ///   - localPath: 本地照片路径
    ///   - remotePath: 远程存储路径
    /// - Returns: 是否传输成功
    func transferSinglePhoto(localPath: String, remotePath: String) -> Bool {
        // 实现SSH文件传输逻辑
        print("模拟照片传输 - 本地路径: \(localPath), 远程路径: \(remotePath)")
        return true
    }
    
    /// 批量传输照片到远程系统
    /// - Parameter photos: 包含本地路径和远程路径的照片字典
    /// - Returns: 成功传输的照片数量
    func batchTransferPhotos(photos: [(local: String, remote: String)]) -> Int {
        var successCount = 0
        for photo in photos {
            if transferSinglePhoto(localPath: photo.local, remotePath: photo.remote) {
                successCount += 1
            }
        }
        print("批量传输完成，成功传输 \(successCount) 张照片")
        return successCount
    }
    
    /// 检查远程系统的可用存储空间
    /// - Returns: 可用空间大小（字节）
    func checkRemoteStorageSpace() -> Int64? {
        // 实现检查远程存储空间的逻辑
        print("模拟检查远程存储空间")
        return 1024 * 1024 * 1024 // 假设1GB可用空间
    }
    
    /// 在远程系统创建目录
    /// - Parameter path: 要创建的目录路径
    /// - Returns: 是否创建成功
    func createRemoteDirectory(path: String) -> Bool {
        // 实现创建远程目录的逻辑
        print("模拟创建远程目录: \(path)")
        return true
    }
    
    /// 关闭SSH会话
    func closeConnection() {
        // 实现关闭SSH会话的逻辑
        print("模拟关闭SSH会话")
    }
}
