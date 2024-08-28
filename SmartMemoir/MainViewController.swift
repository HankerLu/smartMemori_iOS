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
    
    @IBAction func selectButtonTapped(_ sender: UIButton) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
       if let selectedImage = info[.originalImage] as? UIImage {
           mainImageView.image = selectedImage
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
