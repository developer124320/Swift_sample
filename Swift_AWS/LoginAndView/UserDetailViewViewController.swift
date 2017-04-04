//
//  UserDetailViewViewController.swift
//  LoginAndView
//
//  Created by Admin on 03/04/2017.
//  Copyright © 2017 Dubal, Rohan. All rights reserved.
//

import UIKit
import AWSCognitoIdentityProvider
import AWSS3

class UserDetailViewViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var response: AWSCognitoIdentityUserGetDetailsResponse?
    var user: AWSCognitoIdentityUser?
    var pool: AWSCognitoIdentityUserPool?
    var pictureUrl: String?
    var myActivityIndicator: UIActivityIndicatorView!
    var uploadFileURL: NSURL!
    var uploadfilename: String?
    @IBOutlet weak var txtUsername: UITextField!
    @IBOutlet weak var txtPhone: UITextField!
    @IBOutlet weak var txtEmail: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var submit: UIButton!

    @IBAction func submit_click(_ sender: Any) {
        var attributes = [AWSCognitoIdentityUserAttributeType]()
        
        if let phoneValue = self.txtPhone.text, !phoneValue.isEmpty {
            let phone = AWSCognitoIdentityUserAttributeType()
            phone?.name = "phone_number"
            phone?.value = phoneValue
            attributes.append(phone!)
        }
        
        if let emailValue = self.txtEmail.text, !emailValue.isEmpty {
            let email = AWSCognitoIdentityUserAttributeType()
            email?.name = "email"
            email?.value = emailValue
            attributes.append(email!)
        }
        if (uploadFileURL) != nil
        {
            if let imagename = UserDefaults.standard.value(forKey: (self.user?.username!)!)
            {
                
                let downloadingFilePath = NSTemporaryDirectory().stringByAppendingPathComponent(path: imagename as! String)
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: downloadingFilePath){
                    let fileURL = NSURL(fileURLWithPath: downloadingFilePath)
                    do {
                        try fileManager.removeItem(at: fileURL as URL)
                    } catch
                    {
                        print(error)
                    }
                }
            }

            self.startUploadingImage()
        }
        if let imgUrl = uploadfilename{
            let feature = AWSCognitoIdentityUserAttributeType()
            feature?.name = "picture"
            feature?.value = imgUrl
            attributes.append(feature!)
        }
        self.user?.update(attributes)
    }
    
    @IBAction func send(_ sender: Any) {
        self.user?.signOut()
        self.title = nil
        self.response = nil
        //        self.tableView.reloadData()
        self.refresh()

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()        
        
        let myIdentityPoolId = "eu-west-1:702a39c2-a6a3-4c67-9174-3afaa4742694"
        let credentialsProvider:AWSCognitoCredentialsProvider = AWSCognitoCredentialsProvider(regionType:AWSRegionType.EUWest1, identityPoolId: myIdentityPoolId)
        let configuration = AWSServiceConfiguration(region:AWSRegionType.EUWest1, credentialsProvider:credentialsProvider)
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration

        self.pool = AWSCognitoIdentityUserPool(forKey: AWSCognitoUserPoolsSignInProviderKey)
        if (self.user == nil) {
            self.user = self.pool?.currentUser()
        }
        setUpActivityIndicator()
        self.refresh()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    func setUpActivityIndicator()
    {
        //Create Activity Indicator
        myActivityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        
        // Position Activity Indicator in the center of the main view
        myActivityIndicator.center = view.center
        
        // If needed, you can prevent Acivity Indicator from hiding when stopAnimating() is called
        myActivityIndicator.hidesWhenStopped = true
        
        myActivityIndicator.backgroundColor = UIColor.white
        
        view.addSubview(myActivityIndicator)
    }
    

    @IBAction func changeImage(_ sender: Any) {
        let myPickerController = UIImagePickerController()
        myPickerController.delegate = self;
        myPickerController.sourceType = UIImagePickerControllerSourceType.photoLibrary
        self.present(myPickerController, animated: true, completion: nil)
    }
    
    @IBAction func signout(_ sender: Any) {
        self.user?.signOut()
        self.title = nil
        self.response = nil
        self.refresh()
    }
    
    func refresh() {
        
        self.myActivityIndicator.startAnimating()
        self.user?.getDetails().continueOnSuccessWith { (task) -> AnyObject? in
            DispatchQueue.main.async(execute: {
                self.response = task.result
                self.title = self.user?.username
//                self.txtUsername.text = self.user?.username
                for atts in (self.response?.userAttributes)!
                {
                    switch atts.name! {
                        case "email":
                            self.txtEmail.text = atts.value
                        case "phone_number":
                            self.txtPhone.text = atts.value
                        case "picture":
                            self.pictureUrl = atts.value
                        default:
                            continue
                    }
                }
                
                self.downloadImage()
            })
            self.myActivityIndicator.stopAnimating()
            return nil
        }
    }
    
    func downloadImage()  {
        if let imagename = UserDefaults.standard.value(forKey: (self.user?.username!)!)
        {
        
        let downloadingFilePath = NSTemporaryDirectory().stringByAppendingPathComponent(path: imagename as! String)
        let fileManager = FileManager.default
            if fileManager.fileExists(atPath: downloadingFilePath){
                self.imageView.image = UIImage(contentsOfFile: downloadingFilePath)
                myActivityIndicator.stopAnimating()
                return
            }
        let downloadingFileURL = URL(fileURLWithPath: downloadingFilePath)
        let downloadRequest = AWSS3TransferManagerDownloadRequest()
        downloadRequest?.bucket = "bibbucket"
        downloadRequest?.key = imagename as? String
        downloadRequest?.downloadingFileURL = downloadingFileURL
        let transferManager = AWSS3TransferManager.default()
        transferManager.download(downloadRequest!).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AnyObject>) -> Any? in
            
            if let error = task.error as? NSError {
                if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
                    switch code {
                    case .cancelled, .paused:
                        break
                    default:
                        print("Error downloading: \(downloadRequest?.key) Error: \(error)")
                    }
                } else {
                    print("Error downloading: \(downloadRequest?.key) Error: \(error)")
                }
                return nil
            }
            print("Download complete for: \(downloadRequest?.key)")
            self.imageView.image = UIImage(contentsOfFile: downloadingFilePath)
            return nil
        })
        }
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        uploadFileURL = info[UIImagePickerControllerReferenceURL] as! NSURL
        
        //getting actual image
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        imageView.image = image
        
        picker.dismiss(animated: true, completion: nil)
    }
    func startUploadingImage()
    {
        //        var localFileName:String?
        if let filePath = uploadFileURL{
            let imageName = filePath.lastPathComponent
            let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as String
            
            // getting local path
            let localPath = (documentDirectory as NSString).appendingPathComponent(imageName!)
            
            let image = imageView.image!
            let fileManager = FileManager.default
            
            let imageData = UIImageJPEGRepresentation(image, 0.99)
            fileManager.createFile(atPath: localPath as String, contents: imageData, attributes: nil)
            
            let fileUrl = NSURL(fileURLWithPath: localPath)
            myActivityIndicator.startAnimating()
            
            let myIdentityPoolId = "eu-west-1:702a39c2-a6a3-4c67-9174-3afaa4742694"
            let credentialsProvider:AWSCognitoCredentialsProvider = AWSCognitoCredentialsProvider(regionType:AWSRegionType.EUWest1, identityPoolId: myIdentityPoolId)
            let configuration = AWSServiceConfiguration(region:AWSRegionType.EUWest1, credentialsProvider:credentialsProvider)
            
            AWSServiceManager.default().defaultServiceConfiguration = configuration
            
            // Set up AWS Transfer Manager Request
            let S3BucketName = "bibbucket"
            let remoteName = "\((self.user?.username!)!)_\(imageName!)"
            
            
            //        uploadfilename =  imageName
            
            let uploadRequest = AWSS3TransferManagerUploadRequest()
            uploadRequest?.body = fileUrl as URL
            uploadRequest?.key = remoteName
            uploadRequest?.bucket = S3BucketName
            uploadRequest?.contentType = "image/jpeg"
            
            
            let transferManager = AWSS3TransferManager.default()
            myActivityIndicator.startAnimating()
            // Perform file upload
            transferManager.upload(uploadRequest!).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AnyObject>) -> Any? in
                if let error = task.error {
                    print("Upload failed with error: (\(error.localizedDescription))")
                    self.myActivityIndicator.stopAnimating()
                }
                if task.result != nil {
                    self.uploadfilename = remoteName
                    UserDefaults.standard.setValue(remoteName, forKey: (self.user?.username!)!)
                    self.myActivityIndicator.stopAnimating()
                }
                return nil
            })
        }
    }

}
extension String {
    func stringByAppendingPathComponent(path: String) -> String {
        let nsSt = self as NSString
        return nsSt.appendingPathComponent(path)
    }
}
