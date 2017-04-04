//
// Copyright 2014-2017 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License").
// You may not use this file except in compliance with the
// License. A copy of the License is located at
//
//     http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is
// distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, express or implied. See the License
// for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import AWSCognitoIdentityProvider
import AWSS3
import AWSCore
import Photos

class SignUpViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var pool: AWSCognitoIdentityUserPool?
    var sentTo: String?
    
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var phone: UITextField!
    @IBOutlet weak var email: UITextField!
    
    var uploadFileURL: NSURL!
    var uploadCompletionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock?
    var myActivityIndicator: UIActivityIndicatorView!
    var uploadfilename: String?
//    var localPath: String?
    
    @IBAction func btnChose_click(_ sender: Any) {
        let myPickerController = UIImagePickerController()
        myPickerController.delegate = self;
        myPickerController.sourceType = UIImagePickerControllerSourceType.photoLibrary
        self.present(myPickerController, animated: true, completion: nil)
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.pool = AWSCognitoIdentityUserPool.init(forKey: AWSCognitoUserPoolsSignInProviderKey)
        setUpActivityIndicator()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        uploadFileURL = info[UIImagePickerControllerReferenceURL] as! NSURL
      
        
        //getting actual image
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        imgView.image = image
        
        picker.dismiss(animated: true, completion: nil)
    }
    
    
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
    
    func generateImageUrl(fileName: String) -> NSURL
    {
        let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory().appending(fileName))
        let data = UIImageJPEGRepresentation(imgView.image!, 0.6)
        do {
            try data!.write(to: fileURL as URL, options: Data.WritingOptions.atomic)
        } catch
        {
            print(error)
        }

//        data!.writeToURL(fileURL, atomically: true)
        
        return fileURL
    }
    func remoteImageWithUrl(fileName: String)
    {
        let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory().appending(fileName))
        do {
            try FileManager.default.removeItem(at: fileURL as URL)
        } catch
        {
            print(error)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let signUpConfirmationViewController = segue.destination as? ConfirmSignUpViewController {
            signUpConfirmationViewController.sentTo = self.sentTo
            signUpConfirmationViewController.user = self.pool?.getUser(self.username.text!)
        }
    }
    
    @IBAction func signUp(_ sender: AnyObject) {
        
        startUploadingImage()
        guard let userNameValue = self.username.text, !userNameValue.isEmpty,
            let passwordValue = self.password.text, !passwordValue.isEmpty else {
                let alertController = UIAlertController(title: "Missing Required Fields",
                                                        message: "Username / Password are required for registration.",
                                                        preferredStyle: .alert)
                let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                alertController.addAction(okAction)
                
                self.present(alertController, animated: true, completion:  nil)
                return
        }
        
        var attributes = [AWSCognitoIdentityUserAttributeType]()
        
        if let phoneValue = self.phone.text, !phoneValue.isEmpty {
            let phone = AWSCognitoIdentityUserAttributeType()
            phone?.name = "phone_number"
            phone?.value = phoneValue
            attributes.append(phone!)
        }
        
        if let emailValue = self.email.text, !emailValue.isEmpty {
            let email = AWSCognitoIdentityUserAttributeType()
            email?.name = "email"
            email?.value = emailValue
            attributes.append(email!)
        }
        
        if let name = self.username.text, !name.isEmpty {
            let username = AWSCognitoIdentityUserAttributeType()
            username?.name = "name"
            username?.value = name
            attributes.append(username!)
        }
        if let imgUrl = uploadfilename{
            let feature = AWSCognitoIdentityUserAttributeType()
            feature?.name = "picture"
            feature?.value = imgUrl
            attributes.append(feature!)
        }
        else{
            let feature = AWSCognitoIdentityUserAttributeType()
            feature?.name = "picture"
            feature?.value = ""
            attributes.append(feature!)
        }
        
        //sign up the user
        self.pool?.signUp(userNameValue, password: passwordValue, userAttributes: attributes, validationData: nil).continueWith {[weak self] (task) -> Any? in
            guard let strongSelf = self else { return nil }
            DispatchQueue.main.async(execute: {
                if let error = task.error as? NSError {
                    let alertController = UIAlertController(title: error.userInfo["__type"] as? String,
                                                            message: error.userInfo["message"] as? String,
                                                            preferredStyle: .alert)
                    let retryAction = UIAlertAction(title: "Retry", style: .default, handler: nil)
                    alertController.addAction(retryAction)
                    
                    self?.present(alertController, animated: true, completion:  nil)
                } else if let result = task.result  {
                    // handle the case where user has to confirm his identity via email / SMS
                    if (result.user.confirmedStatus != AWSCognitoIdentityUserStatus.confirmed) {
                        strongSelf.sentTo = result.codeDeliveryDetails?.destination
                        strongSelf.performSegue(withIdentifier: "confirmSignUpSegue", sender:sender)
                    } else {
                        let _ = strongSelf.navigationController?.popToRootViewController(animated: true)
                    }
                }
                
            })
            return nil
        }
    }
    
    func startUploadingImage()
    {
//        var localFileName:String?
        if let filePath = uploadFileURL{
        let imageName = filePath.lastPathComponent
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as String
        
        // getting local path
        let localPath = (documentDirectory as NSString).appendingPathComponent(imageName!)

        let image = imgView.image!
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
        let remoteName = "\(self.username.text!)_\(imageName!)"
        
        
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
//                let url = AWSS3.default().configuration.endpoint.url
//                let publicURL = url?.appendingPathComponent((uploadRequest?.bucket!)!).appendingPathComponent((uploadRequest?.key!)!)
//                let s3URL = NSURL(string: "https://s3.amazonaws.com/\(S3BucketName)/\(uploadRequest?.key!)")!
//                print("Uploaded to:\n\(s3URL)")
//                // Remove locally stored file
//                self.remoteImageWithUrl(fileName: (uploadRequest?.key!)!)
//                print("Uploaded to:\(publicURL)")
                self.uploadfilename = remoteName
                UserDefaults.standard.setValue(remoteName, forKey: self.username.text!)
                self.myActivityIndicator.stopAnimating()
            }
            return nil
        })
        }
    }
}
