//
//  TrackLink.swift
//  Tracks
//
//  Created by John Sloan on 8/6/15.
//  Copyright (c) 2015 JPGS inc. All rights reserved.
//

import UIKit
import CoreData

class TrackLink: UIView, AVAudioPlayerDelegate {
   
    var trackNodeIDs: [AVAudioPlayer:TrackLinkNode] = [AVAudioPlayer:TrackLinkNode]()
    var rootTrackID: String!
    var rootTrackAudioPlayer: AVAudioPlayer!
    var mode = ""
    var linkID = ""
    var curTouchedTrack: Track!
    var curTouchLoc: CGPoint!
    var touchHitEdge: Bool = false
    var wasDragged: Bool = false
    var queuedTrackForAdding: Track!
    var appDel: AppDelegate!
    var context: NSManagedObjectContext!
    
    init (frame: CGRect, withTrack track: Track) {
        super.init(frame: frame)
        
        appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        context = appDel.managedObjectContext!
        
        //Set the link id
        if linkID.isEmpty {
            let currentDateTime = NSDate()
            let formatter = NSDateFormatter()
            formatter.dateFormat = "ddMMyyyy-HHmmss-SSS"
            linkID = "link-" + formatter.stringFromDate(currentDateTime)
        }
        
        self.backgroundColor = UIColor.clearColor().colorWithAlphaComponent(0.0)
        rootTrackID = track.trackID
        rootTrackAudioPlayer = track.audioPlayer
        var rootNode = TrackLinkNode(track: track)
        trackNodeIDs[rootTrackAudioPlayer] = rootNode
        setNeedsDisplay()
    }
    
    init (frame: CGRect, withTrackNodeIDs trackNodeIDs: [AVAudioPlayer:TrackLinkNode], rootTrackID root: String, linkID: String) {
        super.init(frame: frame)
        
        appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        context = appDel.managedObjectContext!
        
        self.trackNodeIDs = trackNodeIDs
        self.linkID = linkID
        self.rootTrackID = root
        self.backgroundColor = UIColor.clearColor().colorWithAlphaComponent(0.0)
        setNeedsDisplay()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func touchBegan(touches: NSSet, withEvent event: UIEvent) {
        println("TOUCHED TRACKLINK BEGAN")
        var touch: UITouch = touches.anyObject() as! UITouch
        var touchLoc: CGPoint = touch.locationInView(self)
        
        if mode == "ADD_SEQ_LINK" || mode == "ADD_SIMUL_LINK" {
            var highestIndex = -1
            for audioPlayer in trackNodeIDs.keys {
                var trackID = trackNodeIDs[audioPlayer]!.rootTrackID
                var track = (self.superview as! LinkManager).getTrackByID(trackID)
                var trackIndex = (self.superview as! LinkManager).getTrackIndex(track!)
                if trackIndex > highestIndex && track!.frame.contains(touchLoc) {
                    highestIndex = trackIndex
                    curTouchedTrack = track
                }
            }
            curTouchLoc = touchLoc
        } else {
            var didTouchTrack = false
            touchHitEdge = true
            
            //Make a dictionary of the track nodes with the current z-order index
            var trackSubviews = [Int: Track]()
            for audioPlayer in trackNodeIDs.keys {
                var trackID = trackNodeIDs[audioPlayer]!.rootTrackID
                var track = (self.superview as! LinkManager).getTrackByID(trackID)
                var trackIndex = (self.superview as! LinkManager).getTrackIndex(track!)
                trackSubviews[trackIndex] = track!
            }
            
            //Now iterate through dictionary, sorted by keys(index), to distribute touch, and check if touch landed on an edge or a node.
            var sortedKeys = Array(trackSubviews.keys).sorted(<)
            for index in sortedKeys {
                var track = (trackSubviews[index] as Track!)
                if track.frame.contains(touchLoc) {
                    curTouchedTrack = track
                    didTouchTrack = true
                    touchHitEdge = false
                    track.touchBegan(touches, withEvent: event)
                } else {
                    track.touchBegan(touches, withEvent: event)
                }
            }
            
            //touch current track last and readjust simullink index for proper ordering.
            if didTouchTrack {
                curTouchedTrack.touchBegan(touches, withEvent: event)
            }
            bringTrackLinkToFront()
            self.setNeedsDisplay()
        }
    }
    
    func touchMoved(touches: NSSet, withEvent event: UIEvent) {
        println("TOUCHED TRACKLINK MOVED")
        var touch: UITouch = touches.anyObject() as! UITouch
        var touchLoc: CGPoint = touch.locationInView(self)
        
        if mode == "ADD_SEQ_LINK" || mode == "ADD_SIMUL_LINK" {
            curTouchLoc = touchLoc
            self.setNeedsDisplay()
        } else {
            if touchHitEdge {
                for audioPlayer in trackNodeIDs.keys {
                    var trackID = trackNodeIDs[audioPlayer]!.rootTrackID
                    var track = (self.superview as! LinkManager).getTrackByID(trackID)
                    track!.touchMoved(touches, withEvent: event)
                }
            } else {
                curTouchedTrack.touchMoved(touches, withEvent: event)
            }
            wasDragged = true
            self.setNeedsDisplay()
        }
    }
    
    func touchEnded(touches: NSSet, withEvent event: UIEvent) {
        println("TOUCHED TRACKLINK ENDED")
        if mode == "ADD_SEQ_LINK" || mode == "ADD_SIMUL_LINK" {
            curTouchLoc = nil
            curTouchedTrack = nil
        } else {
            if wasDragged {
                if touchHitEdge {
                    for audioPlayer in trackNodeIDs.keys {
                        var trackID = trackNodeIDs[audioPlayer]!.rootTrackID
                        var track = (self.superview as! LinkManager).getTrackByID(trackID)
                        track!.touchEnded(touches, withEvent: event)
                    }
                } else {
                    curTouchedTrack.touchEnded(touches, withEvent: event)
                    curTouchedTrack = nil
                }
                wasDragged = false
            } else {
                beginPlaySequence(fromStartTrack: curTouchedTrack)
                curTouchedTrack = nil
            }
            self.setNeedsDisplay()
            bringTrackLinkToFront()
        }
    }
    
    func bringTrackLinkToFront() {
        var supervw = self.superview!
        supervw.insertSubview(self, atIndex: supervw.subviews.count - 4)
    }
    
    func beginPlaySequence(fromStartTrack startTrack: Track) {
        var node = trackNodeIDs[startTrack.audioPlayer]
        if node != nil {
            var rootTrack = (self.superview as! LinkManager).getTrackByID(node!.rootTrackID)
            rootTrack!.audioPlayer.delegate = self
            rootTrack!.playAudio()
            
            var visitedSiblings = NSMutableArray()
            visitedSiblings.addObject(rootTrack!.trackID)
            var siblingQueue = [String]()
            //Append initial siblings.
            for siblingID in node!.siblingIDs {
                siblingQueue.append(siblingID)
            }
            //continue adding siblings of siblings to queue until all have been visited.
            while !siblingQueue.isEmpty {
                print("SIBLING COUNT: ")
                println(siblingQueue.count)
                var sibling = (self.superview as! LinkManager).getTrackByID(siblingQueue.removeAtIndex(0))
                var sibNode = trackNodeIDs[sibling!.audioPlayer]
                sibling!.audioPlayer.delegate = self
                sibling!.playAudio()
                visitedSiblings.addObject(sibling!.trackID)
                for siblingID in sibNode!.siblingIDs {
                    if !visitedSiblings.containsObject(siblingID) {
                        siblingQueue.append(siblingID)
                    }
                }
            }
            
        } else {
            println("startTrack did not belong to this link")
        }
    }
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool) {
        println("finished playing!!!")
        var node = trackNodeIDs[player]!
        //Begin plaing each child and each child's siblings, if any.
        for childID in node.childrenIDs {
            var child = (self.superview as! LinkManager).getTrackByID(childID)
            child!.audioPlayer.delegate = self
            child!.playAudio()
            var childNode = trackNodeIDs[child!.audioPlayer]!
        
            var visitedSiblings = NSMutableArray()
            visitedSiblings.addObject(child!.trackID)
            var siblingQueue = [String]()
            //Append initial siblings.
            for siblingID in childNode.siblingIDs {
                siblingQueue.append(siblingID)
            }
            //continue adding siblings of siblings to queue until all have been visited.
            while !siblingQueue.isEmpty {
                var sibling = (self.superview as! LinkManager).getTrackByID(siblingQueue.removeAtIndex(0))
                var sibNode = trackNodeIDs[sibling!.audioPlayer]
                sibling!.audioPlayer.delegate = self
                sibling!.playAudio()
                visitedSiblings.addObject(sibling!.trackID)
                for siblingID in sibNode!.siblingIDs {
                    if !visitedSiblings.containsObject(siblingID) {
                        siblingQueue.append(siblingID)
                    }
                }
            }
        
        }
    }
    
    func queueTrackForAdding(track: Track) {
        queuedTrackForAdding = track
        self.setNeedsDisplay()
    }
    
    func dequeueTrackFromAdding() {
        if queuedTrackForAdding != nil {
            queuedTrackForAdding.layer.borderWidth = 0
            queuedTrackForAdding.layer.borderColor = UIColor.clearColor().CGColor
            queuedTrackForAdding = nil
            self.setNeedsDisplay()
        }
    }
    
    func commitEdgeToLink() {
        println("ADDING TRACK TO TRACKLINK!")
        //Add queued track to dictionary as a new node
        var newNode = TrackLinkNode(track: queuedTrackForAdding)
        trackNodeIDs[queuedTrackForAdding.audioPlayer] = newNode
        
        if mode == "ADD_SEQ_LINK" {
            //Add queued track to children array of curTouchedTrack
            var node = trackNodeIDs[curTouchedTrack.audioPlayer]
            if node != nil {
                node!.childrenIDs.append(queuedTrackForAdding.trackID)
            }
        } else if mode == "ADD_SIMUL_LINK" {
            //Add queued track to sibling array of curTouchedTrack
            var node = trackNodeIDs[curTouchedTrack.audioPlayer]
            if node != nil {
                node!.siblingIDs.append(queuedTrackForAdding.trackID)
                newNode.siblingIDs.append(node!.rootTrackID)
            }
        }
        dequeueTrackFromAdding()
        updateLinkCoreData()
        self.setNeedsDisplay()
    }
    
    override func drawRect(rect: CGRect) {
        drawLinkEdges()
        drawTrackNodeOutlines()
        if (mode == "ADD_SEQ_LINK" || mode == "ADD_SIMUL_LINK") && curTouchedTrack != nil {
            drawCurLinkAdd()
        }
    }
    
    func drawLinkEdges() {
        var context = UIGraphicsGetCurrentContext()
        
        for audioPlayer in trackNodeIDs.keys {
            
            var node = trackNodeIDs[audioPlayer]!
            var trackID = node.rootTrackID
            var startTrack = (self.superview as! LinkManager).getTrackByID(trackID)
            
            for childTrackID in node.childrenIDs {
                var endTrack = (self.superview as! LinkManager).getTrackByID(childTrackID)
                //For each child, paint line from parent track node.
                CGContextSetStrokeColorWithColor(context, UIColor.redColor().colorWithAlphaComponent(1).CGColor)
                CGContextSetLineWidth(context, 8)
                CGContextBeginPath(context)
                CGContextMoveToPoint(context, startTrack!.center.x, startTrack!.center.y)
                CGContextAddLineToPoint(context, endTrack!.center.x, endTrack!.center.y)
                CGContextStrokePath(context)
            }
            
            for siblingTrackID in node.siblingIDs {
                var endTrack = (self.superview as! LinkManager).getTrackByID(siblingTrackID)
                //For each child, paint line from parent track node.
                CGContextSetStrokeColorWithColor(context, UIColor.blueColor().colorWithAlphaComponent(1).CGColor)
                CGContextSetLineWidth(context, 8)
                CGContextBeginPath(context)
                CGContextMoveToPoint(context, startTrack!.center.x, startTrack!.center.y)
                CGContextAddLineToPoint(context, endTrack!.center.x, endTrack!.center.y)
                CGContextStrokePath(context)
            }

        }
    }
    
    func eraseLineOnTrack(track: Track) {
        //Draws clear fill over track node to erase link line from center to edge of node.
        var outLineFrame = track.frame
        var outline = UIBezierPath(roundedRect: outLineFrame, cornerRadius: 12)
        outline.fillWithBlendMode(kCGBlendModeClear, alpha: 1)
    }
    
    func drawTrackNodeOutlines() {
        for audioPlayer in trackNodeIDs.keys {
            var node = trackNodeIDs[audioPlayer]!
            var trackID = node.rootTrackID
            var track = (self.superview as! LinkManager).getTrackByID(trackID)
            track!.layer.borderWidth = 5
            if !node.siblingIDs.isEmpty && !node.childrenIDs.isEmpty {
                track!.layer.borderColor = UIColor.purpleColor().CGColor
            } else if node.siblingIDs.isEmpty {
                track!.layer.borderColor = UIColor.redColor().CGColor
            } else if node.childrenIDs.isEmpty {
                track!.layer.borderColor = UIColor.blueColor().CGColor
            } else {
                track!.layer.borderColor = UIColor.whiteColor().CGColor
            }
            eraseLineOnTrack(track!)
        }
        
        //Also color currently being added/queued nodes based on mode.
        var color: CGColor!
        switch mode {
        case "ADD_SEQ_LINK":
            color = UIColor.redColor().colorWithAlphaComponent(0.4).CGColor
        case "ADD_SIMUL_LINK":
            color = UIColor.blueColor().colorWithAlphaComponent(0.4).CGColor
        default:
            color = UIColor.whiteColor().colorWithAlphaComponent(0.4).CGColor
        }

        if queuedTrackForAdding != nil {
            queuedTrackForAdding.layer.borderColor = color
            queuedTrackForAdding.layer.borderWidth = 5
        }
        
        if curTouchedTrack != nil {
            curTouchedTrack.layer.borderColor = color
            curTouchedTrack.layer.borderWidth = 5
        }
    }
    
    func drawCurLinkAdd() {
        var context = UIGraphicsGetCurrentContext()
        CGContextBeginPath(context)
        CGContextMoveToPoint(context, curTouchedTrack.center.x, curTouchedTrack.center.y)
        CGContextAddLineToPoint(context, curTouchLoc.x, curTouchLoc.y)
        if mode == "ADD_SEQ_LINK" {
            CGContextSetStrokeColorWithColor(context, UIColor.redColor().colorWithAlphaComponent(1).CGColor)
        } else if mode == "ADD_SIMUL_LINK" {
            CGContextSetStrokeColorWithColor(context, UIColor.blueColor().colorWithAlphaComponent(1).CGColor)
        }
        CGContextSetLineWidth(context, 8)
        CGContextStrokePath(context)
        eraseLineOnTrack(curTouchedTrack)
        if queuedTrackForAdding != nil {
            eraseLineOnTrack(queuedTrackForAdding)
        }
    }
    
    func deleteTrackLink() {
        for audioPlayer in trackNodeIDs.keys {
            var trackID = trackNodeIDs[audioPlayer]!.rootTrackID
            var track = (self.superview as! LinkManager).getTrackByID(trackID)
            track!.layer.borderColor = UIColor.clearColor().CGColor
            track!.layer.borderWidth = 0
        }
        deleteLinkFromCoreData()
        self.removeFromSuperview()
    }
    
    override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
        for audioPlayer in trackNodeIDs.keys {
            var node = trackNodeIDs[audioPlayer]!
            var trackID = node.rootTrackID
            var startTrack = (self.superview as! LinkManager).getTrackByID(trackID)
            if startTrack!.frame.contains(point) {
                return true
            }
            for childTrackID in node.childrenIDs {
                var endTrack = (self.superview as! LinkManager).getTrackByID(childTrackID)
                var edge = LinkEdge(startTrackNode: startTrack!, endTrackNode: endTrack!)
                if edge.containsPoint(point) {
                    return true
                }
            }
            for siblingID in node.siblingIDs {
                var endTrack = (self.superview as! LinkManager).getTrackByID(siblingID)
                var edge = LinkEdge(startTrackNode: startTrack!, endTrackNode: endTrack!)
                if edge.containsPoint(point) {
                    return true
                }
            }
        }
        return false
    }
    
    override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        for audioPlayer in trackNodeIDs.keys {
            var node = trackNodeIDs[audioPlayer]!
            var trackID = node.rootTrackID
            var startTrack = (self.superview as! LinkManager).getTrackByID(trackID)
            if startTrack!.frame.contains(point) {
                return self
            }
            for childTrackID in node.childrenIDs {
                var endTrack = (self.superview as! LinkManager).getTrackByID(childTrackID)
                var edge = LinkEdge(startTrackNode: startTrack!, endTrackNode: endTrack!)
                if edge.containsPoint(point) {
                    return self
                }
            }
            for siblingID in node.siblingIDs {
                var endTrack = (self.superview as! LinkManager).getTrackByID(siblingID)
                var edge = LinkEdge(startTrackNode: startTrack!, endTrackNode: endTrack!)
                if edge.containsPoint(point) {
                    return self
                }
            }
        }
        return nil
    }

    func updateLinkCoreData() {
        println("Updating link data")
        var request = NSFetchRequest(entityName: "LinkEntity")
        request.returnsObjectsAsFaults = false
        request.predicate = NSPredicate(format: "linkID = %@", argumentArray: [linkID])
        var results: NSArray = context.executeFetchRequest(request, error: nil)!
        if results.count == 1 {
            var linkEntity = results[0] as! LinkEntity
            
            //update tracklink nodes
            var nodeArray = [TrackLinkNode]()
            for node in trackNodeIDs.values {
                nodeArray.append(node)
            }
            var nodeData = NSKeyedArchiver.archivedDataWithRootObject(nodeArray)
            linkEntity.linkNodes = nodeData
            linkEntity.rootTrackID = rootTrackID
        } else {
            println("MULTIPLE LINKS WITH SAME ID!")
        }
        context.save(nil)
    }
    
    func saveLinkCoreData(projectEntity: ProjectEntity) {
        println("first save of simul link: " + linkID)
        
        //Create array of link nodes from trackNodeIDs dictionary.
        var nodeArray = [TrackLinkNode]()
        for node in trackNodeIDs.values {
            nodeArray.append(node)
        }
        var nodeData = NSKeyedArchiver.archivedDataWithRootObject(nodeArray)
        
        var linkEntity = NSEntityDescription.insertNewObjectForEntityForName("LinkEntity", inManagedObjectContext: context) as! LinkEntity
        linkEntity.linkNodes = nodeData
        linkEntity.project = projectEntity
        linkEntity.rootTrackID = rootTrackID
        linkEntity.linkID = linkID
        context.save(nil)
    }
    
    func deleteLinkFromCoreData() {
        var request = NSFetchRequest(entityName: "LinkEntity")
        request.returnsObjectsAsFaults = false
        request.predicate = NSPredicate(format: "linkID = %@", argumentArray: [linkID])
        var results: NSArray = context.executeFetchRequest(request, error: nil)!
        if results.count == 1 {
            var linkToDelete = results[0] as! LinkEntity
            context.deleteObject(linkToDelete)
            context.save(nil)
        }  else {
            println("MULTIPLE LINKS WITH SAME ID!")
        }
    }    
}