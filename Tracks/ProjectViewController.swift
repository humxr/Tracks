
//
//  ViewController.swift
//  Tracks
//
//  Created by John Sloan on 1/28/15.
//  Copyright (c) 2015 JPGS inc. All rights reserved.
//

import UIKit
import QuartzCore
import CoreData

class ProjectViewController: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate {
    
    var filemanager = NSFileManager.defaultManager()
    var projectDirectory: String!
    var createProjectFolder = true
    var projectID: String = ""
    var projectName: String = ""
    var projectEntity: ProjectEntity!
    var appDel: AppDelegate!
    var context: NSManagedObjectContext!
    var tracks: NSMutableArray = []
    var notesView: UITextView!
    var notesExpanded: Bool!
    var statusBarBackgroundView: UIVisualEffectView!
    var sideBarOpenBackgroundView: UIView!
    var drawView: DrawView!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var navBarVertConstraint: NSLayoutConstraint!
    @IBOutlet weak var linkManager: LinkManager!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var toolbarVertConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add draw view
        drawView = DrawView(frame: self.view.frame)
        drawView.backgroundColor = UIColor.clearColor()
        drawView.layer.backgroundColor = UIColor(red: 0.969, green: 0.949, blue: 0.922, alpha: 1.0).CGColor
        self.view.addSubview(self.drawView)
        
        //Make toolbar transparent
        self.toolbar.setBackgroundImage(UIImage(),
            forToolbarPosition: UIBarPosition.Any,
            barMetrics: UIBarMetrics.Default)
        self.toolbar.setShadowImage(UIImage(),
            forToolbarPosition: UIBarPosition.Any)
        
        // Create effect
        let blur = UIBlurEffect(style: UIBlurEffectStyle.ExtraLight)
        
        // Add effect to an effect view
        statusBarBackgroundView = UIVisualEffectView(effect: blur)
        statusBarBackgroundView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 20 + navigationBar.frame.height);
        
        // Add the effect view
        self.view.addSubview(statusBarBackgroundView)
        
        self.navigationBar.setBackgroundImage(UIImage(), forBarMetrics: UIBarMetrics.Default)
        self.navigationBar.shadowImage = UIImage()
        self.navigationBar.translucent = true
        
        // Create notesView
        notesView = NotesTextView(frame: CGRect(x: 0, y: self.view.frame.height, width: self.view.frame.width, height: 0.0))
        notesExpanded = false
        
        // Check if project folder already exists
        let docDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String
        let allProjects = filemanager.contentsOfDirectoryAtPath(docDirectory, error: nil)
        for project in allProjects! {
            if project as! NSString == projectID {
                createProjectFolder = false
                break
            }
        }
        
        // Create new folder for project if needed. stores audio files in this location.
        if createProjectFolder {
            println("CREATING NEW PROJECT FOLDER")
            let newDirectory = docDirectory.stringByAppendingPathComponent(projectID)
            var error: NSError?
            if filemanager.createDirectoryAtPath(newDirectory, withIntermediateDirectories: true, attributes: nil, error: &error) {
                projectDirectory = newDirectory
            } else {
                println("could not make new project directory: \(error!.localizedDescription) ")
            }
        } else {
            println("LOADING OLD PROJECT")
            projectDirectory = docDirectory.stringByAppendingPathComponent(projectID)
        }
        
        // Assign context, and its core data project entity if it exists.
        appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        context = appDel.managedObjectContext!
        
        var request = NSFetchRequest(entityName: "ProjectEntity")
        request.returnsObjectsAsFaults = false
        request.predicate = NSPredicate(format: "projectID = %@", argumentArray: [projectID])
        var results: NSArray = context.executeFetchRequest(request, error: nil)!
      
        if results.count < 1 {
            projectEntity =  NSEntityDescription.insertNewObjectForEntityForName("ProjectEntity", inManagedObjectContext: context) as! ProjectEntity
            projectEntity.projectID = projectID
            if drawView != nil {
                drawView.saveAllPaths(projectEntity)
            }
        } else {
            projectEntity = results[0] as! ProjectEntity
            drawView.projectEntity = projectEntity
            drawView.loadAllPaths()
        }
        
        //Pass on the project entity to give to newly-added links
        linkManager.projectEntity = projectEntity
        
        loadTracks()
        loadLinks()
        self.view.addSubview(notesView)
        self.view.bringSubviewToFront(statusBarBackgroundView)
        self.view.bringSubviewToFront(navigationBar)
        self.view.bringSubviewToFront(toolbar)
    }
    
    override func viewDidLayoutSubviews() {
        titleTextField.text = projectName
        titleTextField.textAlignment = NSTextAlignment.Center
        titleTextField.delegate = self
        
        // Make navigationBar clear
        navigationBar.backgroundColor = UIColor.clearColor().colorWithAlphaComponent(0.0)
        drawView.frame = self.view.frame
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addTrack(sender: UIBarButtonItem) {
        //Create new Track and set project directory where sound files will be stored.
        var newTrack = Track(frame: CGRect(x: self.view.center.x,y: self.view.center.y,width: 100.0,height: 100.0))
        newTrack.projectDirectory = projectDirectory
        
        //Center and add the new track node.
        newTrack.center = self.view.center
        newTrack.setLabelNameText("untitled")
        newTrack.saveTrackCoreData(projectEntity)
        
        println("IN FOR LOOP")
        for subview in self.view.subviews {
            println(subview)
        }
        println("END FOR LOOP")
        tracks.addObject(newTrack)
        self.view.insertSubview(newTrack, atIndex: self.view.subviews.count - 3)
    }
        
    @IBAction func openSideBarVC(sender: UIBarButtonItem) {
        sideBarOpenBackgroundView = UIView(frame: self.view.frame)
        sideBarOpenBackgroundView.backgroundColor = UIColor.darkGrayColor().colorWithAlphaComponent(0.0)
        var tapGesture = UITapGestureRecognizer(target: self, action: "closeSideBarVC:")
        tapGesture.numberOfTapsRequired = 1
        sideBarOpenBackgroundView.addGestureRecognizer(tapGesture)
        drawView.sideBarOpenLock = true
        self.view.addSubview(sideBarOpenBackgroundView)
        UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: { () -> Void in
            self.sideBarOpenBackgroundView.backgroundColor = UIColor.darkGrayColor().colorWithAlphaComponent(0.5)
            }, completion: { (bool:Bool) -> Void in
        })
        
        (parentViewController as! ProjectManagerViewController).openSideBarVC()
    }
        
    func closeSideBarVC(gestureRecognizer:UIGestureRecognizer) {
        UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: { () -> Void in
                self.sideBarOpenBackgroundView.backgroundColor = UIColor.darkGrayColor().colorWithAlphaComponent(0.0)
            }, completion: { (bool:Bool) -> Void in
                self.sideBarOpenBackgroundView.removeFromSuperview()
        })
        
        (parentViewController as! ProjectManagerViewController).closeSideBarVC()
        drawView.sideBarOpenLock = false
    }
    
    func sideBarClosed() {
        if sideBarOpenBackgroundView != nil {
            sideBarOpenBackgroundView.removeFromSuperview()
        }
    }
    
    @IBAction func addLinkMode(sender: UIBarButtonItem) {
        if linkManager.mode != "ADD_SIMUL_LINK" {
            linkManager.mode = "ADD_SIMUL_LINK"
            for link in linkManager.allSimulLink {
                link.mode = "ADD_SIMUL_LINK"
            }
            UIView.animateWithDuration(0.25, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: { () -> Void in
                //change background color and remove toolbars to show current mode
                self.drawView.layer.backgroundColor = UIColor.darkGrayColor().CGColor
                self.navBarVertConstraint.constant -= self.navigationBar.frame.height + self.navigationBar.frame.origin.y
                self.toolbarVertConstraint.constant -= self.toolbar.frame.height
                self.statusBarBackgroundView.frame.origin.y -= self.statusBarBackgroundView.frame.height
                self.view.layoutIfNeeded()
                }) { (bool:Bool) -> Void in
            }
        }
        
        //create exit button and add to view
        var exitButton = UIButton(frame: CGRect(x: 20, y: self.view.frame.height - 40, width: 20, height: 20))
        var image = UIImage(named: "close-button")
        exitButton.setImage(image, forState: UIControlState.Normal)
        exitButton.addTarget(self, action: "exitAddLinkMode:", forControlEvents: UIControlEvents.TouchUpInside)
        exitButton.adjustsImageWhenHighlighted = true
        self.view.insertSubview(exitButton, atIndex: 4)
    }
    
    func exitAddLinkMode(sender: UIButton) {
        if linkManager.mode == "ADD_SIMUL_LINK" {
            linkManager.mode = ""
            for link in linkManager.allSimulLink {
                link.mode = ""
            }
            UIView.animateWithDuration(0.25, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: { () -> Void in
                self.drawView.layer.backgroundColor = UIColor(red: 0.969, green: 0.949, blue: 0.922, alpha: 1.0).CGColor
                self.navBarVertConstraint.constant += self.navigationBar.frame.height + 20
                self.toolbarVertConstraint.constant += self.toolbar.frame.height
                self.statusBarBackgroundView.frame.origin.y += self.statusBarBackgroundView.frame.height
                self.view.layoutIfNeeded()
                }) { (bool:Bool) -> Void in
            }
            self.view.bringSubviewToFront(navigationBar)
            sender.removeFromSuperview()
        }
    }
    
    @IBAction func stopAudio(sender: UIBarButtonItem) {
        for track in tracks {
            (track as! Track).stopAudio()
        }
    }
    
    @IBAction func undoDraw(sender: UIBarButtonItem) {
        println("UNDODRAW")
        drawView.undoDraw()
    }
   
    @IBAction func toggleNotes(sender: UIBarButtonItem) {
        self.view.insertSubview(notesView, atIndex: self.view.subviews.count - 4)
        if notesExpanded! {
            var tmpFrame: CGRect = notesView.frame
            tmpFrame.size.height = 0
            tmpFrame.origin.y = self.view.frame.height
            UIView.beginAnimations("", context: nil)
            UIView.setAnimationDuration(0.2)
            notesView.frame = tmpFrame
            UIView.commitAnimations()
            notesExpanded = false
        } else {
            var tmpFrame: CGRect = notesView.frame
            tmpFrame.size.height = 460 - toolbar.frame.height
            tmpFrame.size.width = self.view.frame.width
            tmpFrame.origin.y = self.view.frame.height - 460
            UIView.beginAnimations("", context: nil)
            UIView.setAnimationDuration(0.2)
            notesView.frame = tmpFrame
            UIView.commitAnimations()
            notesExpanded = true
        }

    }
    
    @IBAction func enterTrashMode(sender: UIBarButtonItem) {
        if linkManager.mode != "TRASH" {
            linkManager.mode = "TRASH"
            UIView.animateWithDuration(0.25, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: { () -> Void in
                    self.drawView.layer.backgroundColor = UIColor.redColor().colorWithAlphaComponent(0.5).CGColor
                    self.navBarVertConstraint.constant -= self.navigationBar.frame.height + self.statusBarBackgroundView.frame.height
                    self.toolbarVertConstraint.constant -= self.toolbar.frame.height + 15
                    self.statusBarBackgroundView.frame.origin.y -= self.statusBarBackgroundView.frame.height
                    self.view.layoutIfNeeded()
                }) { (bool:Bool) -> Void in
            }
            var exitTrashModeButton = UIButton(frame: CGRect(x: self.view.frame.width - 40, y: self.view.frame.height - 40, width: 20, height: 20))
            var image = UIImage(named: "close-button")
            exitTrashModeButton.setImage(image, forState: UIControlState.Normal)
            exitTrashModeButton.addTarget(self, action: "exitTrashMode:", forControlEvents: UIControlEvents.TouchUpInside)
            exitTrashModeButton.adjustsImageWhenHighlighted = true
            self.view.insertSubview(exitTrashModeButton, atIndex: 4)
        }
    }
    
    func exitTrashMode(sender: UIButton) {
        if linkManager.mode == "TRASH" {
            linkManager.mode = ""
            UIView.animateWithDuration(0.25, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: { () -> Void in
                self.drawView.layer.backgroundColor = UIColor(red: 0.969, green: 0.949, blue: 0.922, alpha: 1.0).CGColor
                self.navBarVertConstraint.constant += self.navigationBar.frame.height + self.statusBarBackgroundView.frame.height
                self.toolbarVertConstraint.constant += self.toolbar.frame.height + 15
                self.statusBarBackgroundView.frame.origin.y += self.statusBarBackgroundView.frame.height
                self.view.layoutIfNeeded()
                }) { (bool:Bool) -> Void in
            }
            sender.removeFromSuperview()
        }
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        titleTextField.resignFirstResponder()
        var projectName = titleTextField.text
        (parentViewController as! ProjectManagerViewController).updateProjectName(projectID, projectName: projectName)
        return true
    }
    
    func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UILongPressGestureRecognizer {
            return true
        } else {
            return false
        }
    }
    
    override func supportedInterfaceOrientations() -> Int {
        return Int(UIInterfaceOrientationMask.Portrait.rawValue)
    }
    
    override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
        return UIInterfaceOrientation.Portrait
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
    
    func loadTracks() {
        var request = NSFetchRequest(entityName: "ProjectEntity")
        request.returnsObjectsAsFaults = false
        request.predicate = NSPredicate(format: "projectID = %@", argumentArray: [projectID])
        var results: NSArray = context.executeFetchRequest(request, error: nil)!
        //for result in results {
        if (results.count > 0) {
            var res = results[0] as! ProjectEntity
            for track in res.track {
                var trackEntity = track as! TrackEntity
                var trackToAdd = NSKeyedUnarchiver.unarchiveObjectWithData(trackEntity.track) as! Track
                tracks.addObject(trackToAdd)
                self.view.addSubview(trackToAdd)
            }
        }
    }
    
    func loadLinks() {
        var request = NSFetchRequest(entityName: "ProjectEntity")
        request.returnsObjectsAsFaults = false
        request.predicate = NSPredicate(format: "projectID = %@", argumentArray: [projectID])
        var results: NSArray = context.executeFetchRequest(request, error: nil)!
        //for result in results {
        if (results.count > 0) {
            var res = results[0] as! ProjectEntity
            for link in res.simulLink {
                var simulLinkEntity = link as! SimulLinkEntity
                println("LINK")
                //Get Track and edge IDs (edges are two track ids, start and end)
                var trackIDs = NSKeyedUnarchiver.unarchiveObjectWithData(simulLinkEntity.tracks) as! Array<String>
                var edgeIDs = NSKeyedUnarchiver.unarchiveObjectWithData(simulLinkEntity.edges) as! Array<Array<String>>
                
                //Translate ID to track objects
                var linkEdges = Array<LinkEdge>()
                for edge in edgeIDs {
                    println("edge")
                    var startTrackNode = linkManager.getTrackByID(edge[0])
                    var endTrackNode = linkManager.getTrackByID(edge[1])
                    print("start: ")
                    println(startTrackNode)
                    print("end: ")
                    println(endTrackNode)
                    var newEdge = LinkEdge(startTrackNode: startTrackNode!, endTrackNode: endTrackNode!)
                    linkEdges.append(newEdge)
                }
                
                var linkToAdd = SimulTrackLink(frame: self.view.frame, withTrackIDs: trackIDs, linkEdges: linkEdges, andLinkID: simulLinkEntity.simulLinkID)
                linkManager.allSimulLink.append(linkToAdd)
                self.view.addSubview(linkToAdd)
            }
        }
    }

}
