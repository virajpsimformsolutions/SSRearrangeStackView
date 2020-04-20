//
//  SSRearrangeStackView.swift
//  SSRearrangeStackView
//
//  Created by Viraj Patel on 12/03/20.
//  Copyright © 2020 Viraj Patel. All rights reserved.
//

import Foundation
import UIKit
import AVKit

@objc public protocol SSRearrangeStackViewDelegate {
    /// didBeginRearrange - called when rearrange begins
    @objc optional func didBeginRearrange()
    
    /// Whenever a user drags a subview for a rearrange, the delegate is told whether the direction
    /// was up or down, as well as what the max and min Y values are of the subview
    @objc optional func didDragToRearrange(inUporLeftDirection up: Bool, maxYorX: CGFloat, minYorX: CGFloat)
    
    /// didRearrange - called whenever a subview was rearrange (returns the new index)
    @objc optional func didmoveToIndex(viewIndex orignal: Int, current: Int)
    
    /// didEndRearrange - called when rearrange ends
    @objc optional func didEndRearrange()
}

@IBDesignable
public class SSRearrangeStackView: UIStackView, UIGestureRecognizerDelegate {
    
    /// Setting `rearrangeEnabled` to `true` enables a drag to rearrange behavior like `UITableView`
    @IBInspectable public var rearrangeEnabled: Bool = false {
        didSet {
            self.setRearrangeEnabled(self.rearrangeEnabled)
        }
    }
    public var delegate: SSRearrangeStackViewDelegate?
    
    // Gesture recognizers
    fileprivate var longPressGRS = [UILongPressGestureRecognizer]()
    fileprivate var doubleTapGPS = [UITapGestureRecognizer]()
    
    // Views for rearrange
    fileprivate var temporaryView: UIView!
    fileprivate var temporaryViewForShadow: UIView!
    fileprivate var actualView: UIView!
    
    // Values for rearrange
    fileprivate var rearrange = false
    fileprivate var finalRearrangeFrame: CGRect!
    fileprivate var originalPosition: CGPoint!
    fileprivate var pointForRearrange: CGPoint!
    
    // Appearance Constants
    public var clipsToBoundsWhileRearrange = false
    public var cornerRadii: CGFloat = 5
    @IBInspectable public var temporaryViewScale: CGFloat = 1.05
    @IBInspectable public var otherViewsScale: CGFloat = 0.97
    @IBInspectable public var temporaryViewAlpha: CGFloat = 0.9
    /// The gap created once the long press drag is triggered
    @IBInspectable public var dragHintSpacing: CGFloat = 5
    @IBInspectable public var longPressMinimumPressDuration = 0.2 {
        didSet {
            self.updateMinimumPressDuration()
        }
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        addArranged()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        addArranged()
    }
     
    // MARK:- Rearrange Methods
    
    override public func addArrangedSubview(_ view: UIView) {
        super.addArrangedSubview(view)
        self.addLongPressGestureRecognizerForRearrangeToView(view)
        addDoubleTapPressGestureRecognizerForRearrangeToView(view)
    }
    
    fileprivate func addLongPressGestureRecognizerForRearrangeToView(_ view: UIView) {
        let longPressGR = UILongPressGestureRecognizer(target: self, action: #selector(SSRearrangeStackView.handleLongPress(_:)))
        longPressGR.delegate = self
        longPressGR.minimumPressDuration = self.longPressMinimumPressDuration
        longPressGR.isEnabled = self.rearrangeEnabled
        view.addGestureRecognizer(longPressGR)
        
        self.longPressGRS.append(longPressGR)
    }
    
    fileprivate func addDoubleTapPressGestureRecognizerForRearrangeToView(_ view: UIView) {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        doubleTap.isEnabled = self.rearrangeEnabled
        view.addGestureRecognizer(doubleTap)
        
        self.doubleTapGPS.append(doubleTap)
    }
    
    fileprivate func setRearrangeEnabled(_ enabled: Bool) {
        for longPressGR in self.longPressGRS {
            longPressGR.isEnabled = enabled
        }
        for longPressGR in self.doubleTapGPS {
            longPressGR.isEnabled = enabled
        }
    }
    
    fileprivate func updateMinimumPressDuration() {
        for longPressGR in self.longPressGRS {
            longPressGR.minimumPressDuration = self.longPressMinimumPressDuration
        }
    }
    
    @objc internal func handleTapGesture(_ tp: UITapGestureRecognizer) {
        self.actualView = tp.view!
        self.removeArrangedSubview(self.actualView)
        self.actualView.isHidden = true
    }
    
    @objc internal func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        if gr.state == .began {
            self.rearrange = true
            self.delegate?.didBeginRearrange?()
            
            self.actualView = gr.view!
            self.originalPosition = gr.location(in: self)
            axis == .horizontal ? (self.originalPosition.x -= self.dragHintSpacing) : (self.originalPosition.y -= self.dragHintSpacing)
            self.pointForRearrange = self.originalPosition
            self.prepareForRearrange()
            
        } else if gr.state == .changed {
            // Drag the temporaryView
            let newLocation = gr.location(in: self)
            let xOffset = newLocation.x - originalPosition.x
            let yOffset = newLocation.y - originalPosition.y
            let translation = CGAffineTransform(translationX: xOffset, y: yOffset)
            // Replicate the scale that was initially applied in perpareForRearrange:
            let scale = CGAffineTransform(scaleX: self.temporaryViewScale, y: self.temporaryViewScale)
            self.temporaryView.transform = scale.concatenating(translation)
            self.temporaryViewForShadow.transform = translation
            
            // Use the midY of the temporaryView to determine the dragging direction, location
            // maxY and minY are used in the delegate call didDragToRearrange
            let maxY = axis == .horizontal ? self.temporaryView.frame.maxX : self.temporaryView.frame.maxY
            let midY = axis == .horizontal ? self.temporaryView.frame.midX : self.temporaryView.frame.midY
            let minY = axis == .horizontal ? self.temporaryView.frame.minX : self.temporaryView.frame.minY
            let index = self.indexOfArrangedSubview(self.actualView)
            let checkMidYorX = axis == .horizontal ? self.pointForRearrange.x : self.pointForRearrange.y
            if midY > checkMidYorX {
                // Dragging the view down
                self.delegate?.didDragToRearrange?(inUporLeftDirection: false, maxYorX: maxY, minYorX: minY)
                
                if let nextView = self.getNextViewInStack(usingIndex: index) {
                    let nextViewframemidXOrY = axis == .horizontal ? nextView.frame.midX : nextView.frame.midY
                    if midY > nextViewframemidXOrY {
                        
                        // Swap the two arranged subviews
                        UIView.animate(withDuration: 0.2, animations: {
                            self.insertArrangedSubview(nextView, at: index)
                            self.insertArrangedSubview(self.actualView, at: index + 1)
                        })
                        self.delegate?.didmoveToIndex?(viewIndex: self.actualView.tag, current: index + 1)
                        
                        self.finalRearrangeFrame = self.actualView.frame
                        axis == .horizontal ? (self.pointForRearrange.x = self.actualView.frame.midX) : (self.pointForRearrange.y = self.actualView.frame.midY)
                        
                    }
                }
                
            } else {
                // Dragging the view up
                self.delegate?.didDragToRearrange?(inUporLeftDirection: true, maxYorX: maxY, minYorX: minY)
                
                if let previousView = self.getPreviousViewInStack(usingIndex: index) {
                    let previousViewframemidXOrY = axis == .horizontal ? previousView.frame.midX : previousView.frame.midY
                    if midY < previousViewframemidXOrY {
                        
                        // Swap the two arranged subviews
                        UIView.animate(withDuration: 0.2, animations: {
                            self.insertArrangedSubview(previousView, at: index)
                            self.insertArrangedSubview(self.actualView, at: index - 1)
                        })
                        self.delegate?.didmoveToIndex?(viewIndex: self.actualView.tag, current: index - 1)
                        self.finalRearrangeFrame = self.actualView.frame
                        axis == .horizontal ? (self.pointForRearrange.x = self.actualView.frame.midX) : (self.pointForRearrange.y = self.actualView.frame.midY)
                    }
                }
            }
        } else if gr.state == .ended || gr.state == .cancelled || gr.state == .failed {
            self.cleanupUpAfterRearrange()
            self.rearrange = false
            self.delegate?.didEndRearrange?()
        }
    }
    
    fileprivate func prepareForRearrange() {
        
        self.clipsToBounds = self.clipsToBoundsWhileRearrange
        
        // Configure the temporary view
        self.temporaryView = self.actualView.snapshotView(afterScreenUpdates: true)
        self.temporaryView.frame = self.actualView.frame
        self.finalRearrangeFrame = self.actualView.frame
        self.addSubview(self.temporaryView)
        
        // Hide the actual view and grow the temporaryView
        self.actualView.alpha = 0
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            
            self.styleViewsForRearrange()
            
            }, completion: nil)
    }
    
    fileprivate func cleanupUpAfterRearrange() {
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            
            self.styleViewsForEndRearrange()
            
            }, completion: { (Bool) -> Void in
                // Hide the temporaryView, show the actualView
                self.temporaryViewForShadow.removeFromSuperview()
                self.temporaryView.removeFromSuperview()
                self.actualView.alpha = 1
                self.clipsToBounds = !self.clipsToBoundsWhileRearrange
        })
        
    }
    
    fileprivate func addArranged() {
        for rView in self.subviews {
            self.addArrangedSubview(rView)
        }
    }
    
    
    // MARK:- View Styling Methods
   
    fileprivate func styleViewsForRearrange() {
        
        let roundKey = "Round"
        let round = CABasicAnimation(keyPath: "cornerRadius")
        round.fromValue = 0
        round.toValue = self.cornerRadii
        round.duration = 0.1
        round.isRemovedOnCompletion = false
        round.fillMode = kCAFillModeForwards
        
        // Grow, hint with offset, fade, round the temporaryView
        let scale = CGAffineTransform(scaleX: self.temporaryViewScale, y: self.temporaryViewScale)
        let translation = CGAffineTransform(translationX: 0, y: self.dragHintSpacing)
        self.temporaryView.transform = scale.concatenating(translation)
        self.temporaryView.alpha = self.temporaryViewAlpha
        self.temporaryView.layer.add(round, forKey: roundKey)
        self.temporaryView.clipsToBounds = true // Clips to bounds to apply corner radius
        
        // Shadow
        self.temporaryViewForShadow = UIView(frame: self.temporaryView.frame)
        self.insertSubview(self.temporaryViewForShadow, belowSubview: self.temporaryView)
        self.temporaryViewForShadow.layer.shadowColor = UIColor.black.cgColor
        self.temporaryViewForShadow.layer.shadowPath = UIBezierPath(roundedRect: self.temporaryView.bounds, cornerRadius: self.cornerRadii).cgPath
        
        // Shadow animations
        let shadowOpacityKey = "ShadowOpacity"
        let shadowOpacity = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacity.fromValue = 0
        shadowOpacity.toValue = 0.2
        shadowOpacity.duration = 0.2
        shadowOpacity.isRemovedOnCompletion = false
        shadowOpacity.fillMode = kCAFillModeForwards
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = CABasicAnimation(keyPath: "shadowOffset.height")
        shadowOffset.fromValue = 0
        shadowOffset.toValue = 50
        shadowOffset.duration = 0.2
        shadowOffset.isRemovedOnCompletion = false
        shadowOffset.fillMode = kCAFillModeForwards
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadius.fromValue = 0
        shadowRadius.toValue = 20
        shadowRadius.duration = 0.2
        shadowRadius.isRemovedOnCompletion = false
        shadowRadius.fillMode = kCAFillModeForwards
        
        self.temporaryViewForShadow.layer.add(shadowOpacity, forKey: shadowOpacityKey)
        self.temporaryViewForShadow.layer.add(shadowOffset, forKey: shadowOffsetKey)
        self.temporaryViewForShadow.layer.add(shadowRadius, forKey: shadowRadiusKey)
        
        // Scale down and round other arranged subviews
        for subview in self.arrangedSubviews {
            if subview != self.actualView {
                subview.layer.add(round, forKey: roundKey)
                subview.transform = CGAffineTransform(scaleX: self.otherViewsScale, y: self.otherViewsScale)
            }
        }
    }
    
    fileprivate func styleViewsForEndRearrange() {
        
        let squareKey = "Square"
        let square = CABasicAnimation(keyPath: "cornerRadius")
        square.fromValue = self.cornerRadii
        square.toValue = 0
        square.duration = 0.1
        square.isRemovedOnCompletion = false
        square.fillMode = kCAFillModeForwards
        
        // Return drag view to original appearance
        self.temporaryView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        self.temporaryView.frame = self.finalRearrangeFrame
        self.temporaryView.alpha = 1.0
        self.temporaryView.layer.add(square, forKey: squareKey)
        
        // Shadow animations
        let shadowOpacityKey = "ShadowOpacity"
        let shadowOpacity = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacity.fromValue = 0.2
        shadowOpacity.toValue = 0
        shadowOpacity.duration = 0.2
        shadowOpacity.isRemovedOnCompletion = false
        shadowOpacity.fillMode = kCAFillModeForwards
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = CABasicAnimation(keyPath: "shadowOffset.height")
        shadowOffset.fromValue = 50
        shadowOffset.toValue = 0
        shadowOffset.duration = 0.2
        shadowOffset.isRemovedOnCompletion = false
        shadowOffset.fillMode = kCAFillModeForwards
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadius.fromValue = 20
        shadowRadius.toValue = 0
        shadowRadius.duration = 0.4
        shadowRadius.isRemovedOnCompletion = false
        shadowRadius.fillMode = kCAFillModeForwards
        
        self.temporaryViewForShadow.layer.add(shadowOpacity, forKey: shadowOpacityKey)
        self.temporaryViewForShadow.layer.add(shadowOffset, forKey: shadowOffsetKey)
        self.temporaryViewForShadow.layer.add(shadowRadius, forKey: shadowRadiusKey)
        
        // Return other arranged subviews to original appearances
        for subview in self.arrangedSubviews {
            UIView.animate(withDuration: 0.3, animations: {
                subview.layer.add(square, forKey: squareKey)
                subview.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            })
        }
    }
    
    
    // MARK:- Stack View Helper Methods
    
    fileprivate func indexOfArrangedSubview(_ view: UIView) -> Int {
        for (index, subview) in self.arrangedSubviews.enumerated() {
            if view == subview {
                return index
            }
        }
        return 0
    }
    
    fileprivate func getPreviousViewInStack(usingIndex index: Int) -> UIView? {
        if index == 0 { return nil }
        return self.arrangedSubviews[index - 1]
    }
    
    fileprivate func getNextViewInStack(usingIndex index: Int) -> UIView? {
        if index == self.arrangedSubviews.count - 1 { return nil }
        return self.arrangedSubviews[index + 1]
    }
    
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !self.rearrange
    }

}
