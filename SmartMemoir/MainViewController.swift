//
//  MainViewController.swift
//  SmartMemoir
//
//  Created by Hanker Lu on 2024/8/28.
//

import UIKit
import Speech


class MainViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {

    @IBOutlet weak var mainImageView: UIImageView!
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var switchButton: UIButton!
    @IBOutlet weak var debugListButton: UIButton!
    @IBOutlet weak var speechButton: UIButton!
    @IBOutlet weak var sendAIButton: UIButton!
    
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

    
    
    @IBAction func zhipuAIButtonTapped(_ sender: UIButton) {
        // sentZhipuAIMessageWithContent()
        sentZhipuAIMessageWithContentStream()
    }

    // 处理流式响应的函数
    func sentZhipuAIMessageWithContentStream() {
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
        
        sendZhipuAiRequestStream(messages: [["role": "user", "content": final_content]]) { result in
            switch result {
            case .success(let content):
                // print("智谱AI返回内容(流式传输): \(content)")
                // 处理流式响应
                if let data = content.data(using: .utf8) {
                    self.handleStreamResponse(data: data)
                }
            case .failure(let error):
                print("智谱AI请求错误(流式传输): \(error)")
                // 在这里处理请求错误
            }
        }
    }
    
    // 处理流式响应的函数
    func handleStreamResponse(data: Data) {
        print("处理流式响应")
        
        // 将数据转换为字符串
        guard let string = String(data: data, encoding: .utf8) else {
            print("无法将数据转换为字符串")
            return
        }
        
        // 按行分割响应
        let lines = string.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix("data: ") {
                let content = String(line.dropFirst(6))
                
                if content == "[DONE]" {
                    print("流式响应结束")
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
                            // print("接收到的内容片段：\(text)")
                            // 在这里处理接收到的内容片段
                        }
                    } catch {
                        print("解析 JSON 时出错：\(error)")
                    }
                }
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
        
        // 创建并执行网络请求任务
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            print("流式传输")
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "没有数据返回", code: 0, userInfo: nil)))
                return
            }
            // print("原始返回的报文内容: \(String(data: data, encoding: .utf8) ?? "无法解析")")
            completion(.success(String(data: data, encoding: .utf8) ?? "无法解析"))
        }
        
        // 开始网络请求任务
        print("开始网络请求任务")
        task.resume()
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

    override func viewDidLoad() {
        super.viewDidLoad()

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