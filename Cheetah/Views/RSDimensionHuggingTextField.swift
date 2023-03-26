//
//  RSDimensionHuggingTextField.swift
//  RSUIKit
//
//  Created by Daniel Jalkut on 6/13/18.
//  Copyright © 2018 Red Sweater. All rights reserved.
//

import Cocoa

// You probably want to use one of RSHeightHuggingTextField or RSWidthHuggingTextField, below

open class RSDimensionHuggingTextField: NSTextField {

    public enum Dimension {
        case vertical
        case horizontal
    }

    var huggedDimension: Dimension

    init(frame frameRect: NSRect, huggedDimension: Dimension) {
        self.huggedDimension = huggedDimension
        super.init(frame: frameRect)
    }

    // For subclasses to pass in the dimension setting
    public init?(coder: NSCoder, huggedDimension: Dimension) {
        self.huggedDimension = huggedDimension
        super.init(coder: coder)
    }

    public required init?(coder: NSCoder) {
        // We don't yet support dimension being coded, just default to vertical
        self.huggedDimension = .vertical
        super.init(coder: coder)
    }

    open override var intrinsicContentSize: NSSize {
        get {
            guard let textCell = self.cell else {
                return super.intrinsicContentSize
            }

            // Set up the bounds to induce unlimited sizing in the desired dimension
            var cellSizeBounds = self.bounds
            switch self.huggedDimension {
            case .vertical: cellSizeBounds.size.height = CGFloat(Float.greatestFiniteMagnitude)
            case .horizontal: cellSizeBounds.size.width = CGFloat(Float.greatestFiniteMagnitude)
            }

            // Do the actual sizing
            let nativeCellSize = textCell.cellSize(forBounds: cellSizeBounds)

            // Return an intrinsic size that imposes calculated (hugged) dimensional size
            var intrinsicSize = NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
            switch self.huggedDimension {
            case .vertical:
                intrinsicSize.height = nativeCellSize.height
            case .horizontal:
                intrinsicSize.width = nativeCellSize.width
            }
            return intrinsicSize
        }
    }

    open override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        self.invalidateIntrinsicContentSize()

        // It seems important to set the string from the cell on ourself to
        // get the change to be respected by the cell and to get the cellSize
        // computation to update!
        if let changedCell = self.cell {
            self.stringValue = changedCell.stringValue
        }
    }
}

open class RSHeightHuggingTextField: RSDimensionHuggingTextField {
    @objc init(frame frameRect: NSRect) {
        super.init(frame: frameRect, huggedDimension: .vertical)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder, huggedDimension: .vertical)
    }

    public override init(frame frameRect: NSRect, huggedDimension: Dimension = .vertical) {
        super.init(frame: frameRect, huggedDimension: huggedDimension)
    }
}

open class RSWidthHuggingTextField: RSDimensionHuggingTextField {
    @objc init(frame frameRect: NSRect) {
        super.init(frame: frameRect, huggedDimension: .horizontal)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder, huggedDimension: .horizontal)
    }

    public override init(frame frameRect: NSRect, huggedDimension: Dimension = .horizontal) {
        super.init(frame: frameRect, huggedDimension: huggedDimension)
    }
}
