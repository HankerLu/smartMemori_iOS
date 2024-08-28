//
//  MainViewController.swift
//  SmartMemoir
//
//  Created by Hanker Lu on 2024/8/28.
//

import UIKit


class MainViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {

    @IBOutlet weak var mainImageView: UIImageView!
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var switchButton: UIButton!
    @IBOutlet weak var debugListButton: UIButton!
    
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
                        // 假设每个文件名对应的标签为文件名的数组（可以根据实际需求修改）
                        let tags = [fileName] // 这里可以根据需要生成标签
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
