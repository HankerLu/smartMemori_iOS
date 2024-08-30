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

    
    func sendZhipuAiRequest(messages: [[String: String]], completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "无效的URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "model": "your_model_code_here",
            "messages": messages,
            "stream": false,
            "temperature": 0.95,
            "top_p": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "没有数据返回", code: 0, userInfo: nil)))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else {
                    completion(.failure(NSError(domain: "无法解析响应", code: 0, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
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

