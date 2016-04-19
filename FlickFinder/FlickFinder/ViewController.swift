//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    let center = NSNotificationCenter.defaultCenter()

    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        // FIX: As of Swift 2.2, using strings for selectors has been deprecated. Instead, #selector(methodName) should be used.
        subscribeToNotification(UIKeyboardWillShowNotification, selector: #selector(keyboardWillShow))
        subscribeToNotification(UIKeyboardWillHideNotification, selector: #selector(keyboardWillHide))
        subscribeToNotification(UIKeyboardDidShowNotification, selector: #selector(keyboardDidShow))
        subscribeToNotification(UIKeyboardDidHideNotification, selector: #selector(keyboardDidHide))
//        UIScreenBrightnessDidChangeNotification
        
        center.addObserverForName(UIScreenBrightnessDidChangeNotification, object: nil, queue: nil) { notification in
            print("\(notification.name): \(UIScreen.mainScreen().brightness) ?? [:])")
        }
        
        print(UIDevice.currentDevice().model)
    }
    
    deinit {
    
        center.removeObserver(UIScreenBrightnessDidChangeNotification)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String!] = ["text":phraseTextField.text,
                                                       Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                                                       Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                                                       Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                                                       Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                                                       Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                                                       Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback]
            
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String!] = [Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                                                       Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                                                       Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                                                       Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                                                       Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback,
                                                       Constants.FlickrParameterKeys.BoundingBox: bbox(latitudeTextField.text!, long: longitudeTextField.text!)
            ]
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    private func bbox(lat: String, long: String) -> String {
        guard let lat = Double(lat), long = Double(long) else {
            print("Wrong cordinates interpetation")
            return "0,0,0,0"
        }
       
        let minimumLat = lat - Constants.Flickr.SearchBBoxHalfHeight
        let minimumLong = long - Constants.Flickr.SearchBBoxHalfWidth
        let minRanged = rangeCheck(minimumLat, long: minimumLong)
        let maxLat = lat + Constants.Flickr.SearchBBoxHalfHeight
        let maxLong = long + Constants.Flickr.SearchBBoxHalfWidth
        let maxRanged = rangeCheck(maxLat, long: maxLong)
        
        return "\(minRanged.1),\(minRanged.0),\(maxRanged.1),\(maxRanged.0)"
    
    }
    
    func rangeCheck(lat: Double, long: Double) -> (Double, Double) {
        
        let latLoweRange = Constants.Flickr.SearchLatRange.0
        let latUpperRange = Constants.Flickr.SearchLatRange.1
        
        let longUpperRange = Constants.Flickr.SearchLonRange.1
        let longLowerRange = Constants.Flickr.SearchLonRange.0
        
        let latRanged = max(latLoweRange, min(lat, latUpperRange))
        let longRanged = max(longLowerRange, min(long, longUpperRange))
        
        return (latRanged,longRanged)
    }
    
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(methodParameters: [String:AnyObject]) {
        
//        print(flickrURLFromParameters(methodParameters))
        
        
        // TODO: Make request to Flickr!
        let session = NSURLSession.sharedSession()
        let url = flickrURLFromParameters(methodParameters)
        let request = NSURLRequest(URL: url)
 
        let task = session.dataTaskWithRequest(request, completionHandler: {
            data,response,erorr in
            guard let data = data else {
                print("Error request \(erorr?.localizedDescription)")
                return
            }
            
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                print("response code isn't 2xx")
                return
            }
            
            var parsedResults: AnyObject!
            
            do {
                parsedResults = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) 
            } catch {
                print("couldn't serialize JSON")
            }
            
            guard let photos = parsedResults["photos"] as? [String: AnyObject] else {
                print("error parsing head photos")
                return
            }
            
            guard let numPages = photos["pages"] as? Int else {
                print("no pages")
                return
            }
            
            if methodParameters[Constants.FlickrParameterKeys.Page] == nil {
                print("getting random")
                let randPage = arc4random_uniform(UInt32(numPages) + 1)
                var newParams = methodParameters
//                print(randPage)
                newParams[Constants.FlickrParameterKeys.Page] = "\(randPage)"
                self.displayImageFromFlickrBySearch(newParams)
            }else {
                
                guard let responseArray = photos["photo"] as? [AnyObject] else {
                    print("error parsing photos array")
                    return
                }
                if responseArray.count > 0 {
                    let randIndex = arc4random_uniform(UInt32(responseArray.count))
                    let randResult = responseArray[Int(randIndex)]
                    let imageTitle = randResult["title"] as? String
                    
                    guard let imageUrl = randResult["url_m"] as? String else {
                        print("error parsing url")
                        return
                    }
                    
                    guard let imageData = NSData(contentsOfURL: NSURL(string: imageUrl)!) else {
                        print("error requesting image data")
                        return
                    }
                    
                    performUIUpdatesOnMain {
                        self.setUIEnabled(true)
                        self.photoTitleLabel.text = imageTitle ?? "Unknown"
                        self.photoImageView.image = UIImage(data: imageData)
                    }
                }else {
                    print("zero response")
                }
           
                

            }
           
            
            
            })
        
        task.resume()
        
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(parameters: [String:AnyObject]) -> NSURL {
        
        let components = NSURLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [NSURLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = NSURLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.URL!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(notification: NSNotification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.CGRectValue().height
    }
    
    private func resignIfFirstResponder(textField: UITextField) {
        if textField.isFirstResponder() {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    private func isTextFieldValid(textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!) where !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    private func isValueInRange(value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

extension ViewController {
    
    private func setUIEnabled(enabled: Bool) {
        photoTitleLabel.enabled = enabled
        phraseTextField.enabled = enabled
        latitudeTextField.enabled = enabled
        longitudeTextField.enabled = enabled
        phraseSearchButton.enabled = enabled
        latLonSearchButton.enabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

extension ViewController {
    
    private func subscribeToNotification(notification: String, selector: Selector) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    private func unsubscribeFromAllNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}