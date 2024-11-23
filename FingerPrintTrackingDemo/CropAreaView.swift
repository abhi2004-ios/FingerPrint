//
//  CropAreaView.swift
//  FingerPrintTrackingDemo
//
//  Created by DREAMWORLD on 22/11/24.
//

import UIKit

class CropAreaView: UIView {

    @IBOutlet weak var btnBottomRightCorner: UIButton!
    @IBOutlet weak var btnTopRightCorner: UIButton!
    @IBOutlet weak var btnBottomLeftCorner: UIButton!
    @IBOutlet weak var btnTopLeftCorner: UIButton!
    @IBOutlet weak var vwCrop: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        customInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        customInit()
    }

    private func customInit() {
        let nib = UINib(nibName: "CropAreaView", bundle: nil)
        if let view = nib.instantiate(withOwner: self, options: nil).first as? UIView {
            view.backgroundColor = UIColor.clear
            view.isUserInteractionEnabled = true
            addSubview(view)
            view.frame = self.bounds

            self.vwCrop.layer.borderColor = UIColor.white.cgColor
            self.vwCrop.layer.borderWidth = 1.0
        }
    }
}
