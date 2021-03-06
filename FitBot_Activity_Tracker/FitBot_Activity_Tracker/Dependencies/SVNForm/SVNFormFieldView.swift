//
//  SVNFormFieldView.swift
//  LendWallet
//
//  Created by Aaron Dean Bikis on 8/9/17.
//  Copyright © 2017 7apps. All rights reserved.
//

import UIKit

public enum SVNFieldType {
  case toggle, textField, checkMark
}

protocol SVNFormFieldViewDelegate: class {
    func onCheckMarkLabelTap(sender: UIView)
}

public class SVNFormFieldView: UIView, FinePrintCreatable {
  
  weak var delegate: SVNFormFieldViewDelegate!
  
  var yPadding: CGFloat {
    get {
      return 10.0
    }
  }
  
  lazy var textField: SVNFormTextField = {
    let tf = SVNFormTextField(theme: theme)
    self.addSubview(tf)
    return tf
  }()
  
  lazy var checkMarkView: SVNFormCheckMarkView = {
    let check = SVNFormCheckMarkView(theme: theme)
    self.addSubview(check)
    return check
  }()
  
  lazy var toggleView: SVNFormToggleView = {
    let toggle = SVNFormToggleView()
    self.addSubview(toggle)
    return toggle
  }()
  
  lazy var placeholder: SVNFormPlaceholderLabel = {
    let label = SVNFormPlaceholderLabel(theme: theme)
    self.addSubview(label)
    return label
  }()
  
  private lazy var termsLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.textAlignment = .left
    label.isUserInteractionEnabled = true
    self.addSubview(label)
    return label
  }()
  
  var toolTipView: SVNFormDisclosureButton?
  
  var type: SVNFieldType!
  
  var theme: SVNFormTheme
  
  init(withTextFieldData data: SVNFormFieldType, delegate: UITextFieldDelegate, disclosureDelegate: SVNFormDisclosureButtonDelegate, autofillText: String, svnformDelegate: SVNFormTextFieldDelegate, theme: SVNFormTheme){
    self.theme = theme
    super.init(frame: CGRect.zero)
    type = .textField
    textField.setView(forType: data, formDelegate: svnformDelegate, textFieldDelegate: delegate, autoFillText:  autofillText)
    
    placeholder.standardText = data.fieldData.placeholder
    placeholder.refreshView()
    
    addToolTip(for: data, disclosureDelegate: disclosureDelegate)
    
    setBorderStyling()
  }
  
  
  init(withCheckMarkData fieldType: SVNFormFieldType, autoFillText: String, theme: SVNFormTheme){
    self.theme = theme
    super.init(frame: CGRect.zero)
    type = .checkMark
    checkMarkView.setView(asType: fieldType, isChecked: autoFillText != "")
    termsLabel.attributedText = createFinePrintAttributedString(withStrings: fieldType.fieldData.isTerms!.data.terms,
                                                                linkFont: theme.finePrintFont,
                                                                textColor: theme.textFieldTextColor,
                                                                linkColor: theme.buttonColor, alignment: .left)
    termsLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTermsLabelTap)))
  }
  
  
  init(fieldType: SVNFormFieldType, autoFillText: String, placeholderText: String, disclosureDelegate: SVNFormDisclosureButtonDelegate, theme: SVNFormTheme){
    self.theme = theme
    super.init(frame: CGRect.zero)
    type = .toggle
    
    toggleView.setView(withData: fieldType.fieldData.hasToggle!, type: fieldType, autofill: autoFillText)
    
    placeholder.standardText = placeholderText
    placeholder.refreshView()
    
    addToolTip(for: fieldType, disclosureDelegate: disclosureDelegate)
  }
  
  
  private func addToolTip(for fieldType: SVNFormFieldType, disclosureDelegate: SVNFormDisclosureButtonDelegate){
    if let toolTipData = fieldType.fieldData.hasToolTip {
      toolTipView = SVNFormDisclosureButton(data: toolTipData.data, delegate: disclosureDelegate)
      addSubview(toolTipView!)
      
    } else if fieldType.fieldData.hasDatePicker != nil {
      toolTipView = SVNFormDisclosureButton(image: #imageLiteral(resourceName: "Icons_Calendar"))
      addSubview(toolTipView!)
      
    } else if fieldType.fieldData.hasPickerView != nil {
      toolTipView = SVNFormDisclosureButton(image: #imageLiteral(resourceName: "Icons_Dropdown"))
      addSubview(toolTipView!)
    }
  }
  
  
  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  
  override public func layoutSubviews() {
    switch type! {
    case .textField:
      placeholder.frame = CGRect(x: yPadding / 2, y: yPadding / 2,
                                 width: frame.width - yPadding, height: SVNFormPlaceholderLabel.StandardHeight)
      
      let tfY = placeholder.frame.origin.y + placeholder.frame.height
      
      textField.frame = CGRect(x: yPadding / 2, y: tfY,
                               width: frame.width - yPadding, height: SVNFormTextField.StandardHeight)
      
      toolTipView?.frame = CGRect(x: frame.width - 35, y: frame.height / 2 - SVNFormDisclosureButton.StandardSize / 2,
                                  width: SVNFormDisclosureButton.StandardSize, height: SVNFormDisclosureButton.StandardSize)
      
    case .toggle:
      placeholder.frame = CGRect(x: 0, y: 0,
                                 width: frame.width - 55, height: SVNFormPlaceholderLabel.StandardHeight)
      
      toggleView.frame = CGRect(x: 0, y: placeholder.frame.origin.y + placeholder.frame.size.height + SVNFormToggleView.PlaceHolderPadding,
                                width: frame.width, height: SVNFormToggleView.StandardHeight)
      
      toolTipView?.frame = CGRect(x: frame.width - 35, y: (SVNFormPlaceholderLabel.StandardHeight - SVNFormDisclosureButton.StandardSize) / 2,
                                  width: SVNFormDisclosureButton.StandardSize, height: SVNFormDisclosureButton.StandardSize)
      
    case .checkMark:
      let checkMarkContainerWidth = frame.height / 1.5
      
      checkMarkView.frame = CGRect(x: 0, y: frame.height / 2  - checkMarkContainerWidth / 2,
                                   width: checkMarkContainerWidth, height: checkMarkContainerWidth)
      
      let x = checkMarkView.frame.origin.x + checkMarkView.frame.size.width + 10
      
      termsLabel.frame = CGRect(x: x, y: 0,
                                width: frame.width - x, height: frame.height)
    }
  }
  
  @objc private func onTermsLabelTap(){
    delegate.onCheckMarkLabelTap(sender: self)
  }
  
  private func setBorderStyling(){
    layer.borderColor = theme.checkMarkViewBorderColor.cgColor
    layer.borderWidth = 0.5
  }
}
