//
//  ViewController.swift
//  SSRearrangeStackView
//
//  Created by Viraj Patel on 03/12/2020.
//  Copyright (c) 2020 Viraj Patel. All rights reserved.
//

import UIKit
import SSRearrangeStackView

class ViewController: UIViewController {

    @IBOutlet weak var rStackView: SSRearrangeStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        rStackView.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

extension ViewController: SSRearrangeStackViewDelegate {
    
    // Delegate Methods
    func didBeginRearrange() {
        print("Did begin reordering")
    }
    
    func didDragToRearrange(inUporLeftDirection up: Bool, maxYorX: CGFloat, minYorX: CGFloat) {
        print("Dragging: \(up ? "UporLeft" : "DownofRight")")
    }
    
    func didmoveToIndex(viewIndex orignal: Int, current: Int) {
        print("orignal: \(orignal) current: \(current)")
    }
    
    func didEndRearrange() {
        print("Did end reordering")
        
        var resquance: [Int] = []
        for views in rStackView.arrangedSubviews {
            resquance.append(views.tag)
        }
        
        print("resquance \(resquance)")
    }
    
}
