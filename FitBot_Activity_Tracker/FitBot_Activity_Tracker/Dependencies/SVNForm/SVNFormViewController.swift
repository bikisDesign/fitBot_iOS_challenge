//
//  SVNFormViewController.swift
//  Locked
//
//  Created by Aaron bikis on 1/5/18.
//  Copyright © 2018 Bikis Design. All rights reserved.
//

import UIKit
import SVNBootstraper

/**
 A View Controller containing a tableview set to the bounds of the viewController
 Intended to be set as a child of another View Controller.
 To initlize this VC call init(theme:, dataSource: nibNamed:, bundleNamed:)
 To validate textFields call validator.validate()
 Reference didValidateAllFields([LWFormFieldType: String]) as a callback to a sucessful validation
 Tapping Go on the return key type will attempt to validate the textFields resulting in didValidateAllFields being called if successful
 When resizing this viewController make sure to resize the tableview contained within it.
 */

protocol SVNFormViewControllerDelegate: class {
  /** notifies the receiver that the full form was validated
   - Parameter text: A String Array matching the supplied SVNFormViewControllerDataSource in indexing
 */
  func formWasValidated(withText text: [String])
  
  /**
   Called by the form if validation failed. Can override to perform notifications to the user before presenting errors
   Actual field animation handling should be performed by updating the viewModel's style transformation * Not currently supported *
   */
  func notifyUserOfFailedValidation()
  
  /** Notifies the receiver when a tool tip has been tapped.
   Is called on the main thread */
  func forwardingOnToolTipTap(withData data: SVNFormTermsOverlayDataSource)
  
  /** Notifies the receiver that a single field was validated */
  func fieldWasValidated(field: SVNFormField)
  
  /** Notifies the receiver when the scroll view scrolls in a certain direction.
      Perform animations here.
      Is executed on the main thread. */
  func scrollViewContentOffset(isZero: Bool)
  
  /** notifies the receiver that a textField's text changed. Perform all changes in input here.
   i.e. zip code length restrictions, hypenation ...ect */
  func forwarding(_ textField: SVNFormTextField, shouldChangeCharecters range: NSRange, replacement string: String) -> Bool
  
  /** is called before the form is animated upwards the completion handler must be called in order for the form to animate correctly
   the form will animate upwards to y: 0
  if you need to hide or animate other UI elements as the form is animated upwards call them here. */
  func keyboardWillShowNeedTopAndBottomLayoutConstraint() -> (NSLayoutConstraint, NSLayoutConstraint)
}


class SVNFormViewController: UIViewController, KeyboardNotifiable {
  
  internal var actionSheetDatasource: SVNTermsActionSheetDatasource?
  
  lazy var scrollView: UIScrollView = {
    let scroll = UIScrollView()
    scroll.delegate = self as UIScrollViewDelegate
    self.view.addSubview(scroll)
    return scroll
  }()
  
  fileprivate var viewModel: SVNFormViewModel
  
  weak var delegate: SVNFormViewControllerDelegate!
  
  fileprivate lazy var formFields = [SVNFormFieldView]()
  
  private lazy var formFieldFrames = [CGRect]()
  
  private lazy var buttonFrame = CGRect()
  
  lazy var validationButton: SVNLargeButton = {
    let button = SVNLargeButton(frame: CGRect.zero,
                                theme: viewModel.dataSource.theme,
                                dataSource: viewModel.dataSource.buttonData)
    button.addTarget(self, action: #selector(onValidateButtonTap), for: .touchUpInside)
    self.scrollView.addSubview(button)
    return button
  }()
  
  init(withData dataSource: SVNFormViewControllerDataSource, delegate: SVNFormViewControllerDelegate, frame: CGRect){
    viewModel = SVNFormViewModel(dataSource: dataSource)
    super.init(nibName: nil, bundle: nil)
    self.actionSheetDatasource = dataSource.actionSheetData
    view.frame = frame
    self.delegate = delegate
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }
  
  fileprivate var previousStaticScrollViewContentOffSet = CGPoint(x: 0, y: 0)
  
  
  override func viewDidLayoutSubviews() { // since were using autolayout in the containing class we need to update the frames here as well
    
    scrollView.frame = view.bounds
    scrollView.contentSize = CGSize(width: view.bounds.width, height: scrollView.contentSize.height)
    for index in 0..<formFields.count {
      var formFrame = formFieldFrames[index]
      formFrame.size.width = view.bounds.width
      formFields[index].frame = formFrame
    }
    buttonFrame.size.width = view.bounds.width / 2
    buttonFrame.origin.x = (view.bounds.width - view.bounds.width / 2) / 2
    validationButton.frame = buttonFrame
  }
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    viewModel.setStyleTransformers(success: { (rule) in
      
      if let label = rule.errorLabel as? SVNFormPlaceholderLabel {
        label.hasErrorMessage = nil
        
      } else if let field = rule.field as? SVNFormCheckMarkView {
        field.hasErrorMessage = ""
      }
      
    }) { (error) in
      
      if let label = error.errorLabel as? SVNFormPlaceholderLabel {
        label.hasErrorMessage = error.errorMessage
        
      } else if let field = error.field as? SVNFormCheckMarkView {
        field.hasErrorMessage = error.errorMessage
      }
    }
    
    setForm()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    registerForKeyboardNotifications(with: #selector(keyboardWillShowOrHide(_:)))
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterForKeyboardNotifications()
  }
  
  func reload(data dataSource: SVNFormViewControllerDataSource, autofillData: [String]? = nil){
    formFieldFrames.removeAll()
    formFields.forEach({ $0.removeFromSuperview() })
    formFields.removeAll()
    
    viewModel.update(dataSource: dataSource, autofillData: autofillData ?? Array(repeating: "", count: dataSource.formData.count))
    setForm()
    viewDidLayoutSubviews()
  }
  
  
  func updateTextField(atIndex index: Int, text: String, type: SVNFieldType){
    DispatchQueue.main.async { // can be called by an API
      switch type {
      case .toggle:
        self.formFields[index].toggleView.select(withTitle: text)
      case .checkMark:
        self.formFields[index].checkMarkView.isChecked = text != ""
      case .textField:
        self.formFields[index].textField.text = text
      }
    }
  }
  
  
  private func setForm(){
    
    viewModel.setDelegates(forTextField: self as UITextFieldDelegate, forDisclosureButton: self,
                           forSVNTextField: self, forViewModel: self, forFieldView: self)
    
    var accumulatedY = SVNFormViewModel.FieldYpadding
    
    for i in 0..<viewModel.numberOfFields {
      
      let field = viewModel.createField(forRow: i)
      
      let height = viewModel.getHeightForCell(atRow: i)
      
      formFieldFrames.append(CGRect(x: 0, y: accumulatedY,
                                    width: view.bounds.width, height: height))
      
      accumulatedY += (height + SVNFormViewModel.FieldYpadding)
      
      scrollView.addSubview(field)
      
      formFields.append(field)
    }
    
    
    buttonFrame = CGRect(x: 0, y: accumulatedY + SVNLargeButton.standardPadding,
                         width: view.bounds.width, height: SVNLargeButton.standardHeight)
    
    accumulatedY += (SVNLargeButton.standardHeight + (SVNLargeButton.standardPadding * 2) + SVNLargeButton.bottomPadding)
    
    scrollView.contentSize = CGSize(width: view.bounds.width, height: accumulatedY)
  }
  
  
  //MARK: Actions
  @objc private func onValidateButtonTap(){
    view.endEditing(true)
    viewModel.validateForm()
  }
  
  //MARK: keyboard Notification
  @objc func keyboardWillShowOrHide(_ notification: NSNotification) {
    let userInfo = notification.userInfo!
    print(notification)
    print(notification.object ?? "")
    
    // Get information about the animation.
    let animationDuration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
    
    let rawAnimationCurveValue = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).uintValue
    let animationCurve = UIViewAnimationOptions(rawValue: rawAnimationCurveValue)
    
    // Convert the keyboard frame from screen to view coordinates.
    let keyboardScreenBeginFrame = (userInfo[UIKeyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
    let keyboardScreenEndFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
    
    let keyboardViewBeginFrame = view.convert(keyboardScreenBeginFrame, from: view.window!)
    let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window!)
    print(keyboardViewBeginFrame)
    print(keyboardViewEndFrame)
    
    // Determine how far the keyboard has moved up or down.
    let originDelta = keyboardViewEndFrame.origin.y - keyboardViewBeginFrame.origin.y
    print(originDelta)
    print(keyboardViewEndFrame)
    
    
    
    // Inform the view that its the layout should be updated.
    view.setNeedsLayout()
    
    // Animate updating the view's layout by calling layoutIfNeeded inside a UIView animation block.
    let animationOptions: UIViewAnimationOptions = [animationCurve, .beginFromCurrentState]
    UIView.animate(withDuration: animationDuration, delay: 0, options: animationOptions, animations: {
      let layoutConstraints = self.delegate.keyboardWillShowNeedTopAndBottomLayoutConstraint()
      layoutConstraints.0.isActive = false
      layoutConstraints.1.constant = CGFloat(originDelta)
      self.view.setNeedsLayout()
    }, completion: nil)
  }
  
}


extension SVNFormViewController: SVNFormTextFieldDelegate {
  func forwardingToolbarStateChange(withState state: SVNFormToolbarState, sender: SVNFormTextField) {
    switch state {
    case .dismiss:
      sender.resignFirstResponder()
      
    case .next:
      setNextResponder(currentResponder: sender, incrementing: true)
      
    case .previous:
      setNextResponder(currentResponder: sender, incrementing: false)
    }
  }
}

extension SVNFormViewController: SVNFormFieldViewDelegate, TermsActionSheetPresentable {
  
  func onCheckMarkLabelTap(sender: UIView) {
    view.endEditing(true)
    let rect = view.convert(sender.frame, from: sender.superview)
    presentTermsSheetActionAlert(in: rect)
  }
}


extension SVNFormViewController: UITextFieldDelegate {
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    guard let tf = textField as? SVNFormTextField else { fatalError(SVNFormError.notTextFieldSubclass.localizedDescription) }
    return delegate.forwarding(tf, shouldChangeCharecters: range, replacement: string)
  }
  
  func textFieldDidBeginEditing(_ textField: UITextField) {
    guard let tf = textField as? SVNFormTextField else { fatalError(SVNFormError.notTextFieldSubclass.localizedDescription) }
    if tf.type.fieldData.hasProtectedInformation {
      tf.text = ""
    }
  }
  
  
  func textFieldDidEndEditing(_ textField: UITextField) {
    guard let tf = textField as? SVNFormTextField else { fatalError(SVNFormError.notTextFieldSubclass.localizedDescription) }
    viewModel.validate(field: tf)
  }
  
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    setNextResponder(currentResponder: textField, incrementing: true)
    return true
  }
  
  
  fileprivate func setNextResponder(currentResponder textField: UITextField, incrementing: Bool) {
    guard var index = formFields.index(of: textField.superview as! SVNFormFieldView) else { return }
    
    index = incrementing ? index + 1 : index - 1
    
    guard index < formFields.count && index >= 0 else {
      textField.resignFirstResponder()
      return
    }
    
    guard formFields.indices.contains(index) else { return }
    
    let nextField = formFields[index]
    
    if nextField.type == .textField {
      nextField.textField.becomeFirstResponder()
      
    } else {
      textField.resignFirstResponder()
    }
  }
}


extension SVNFormViewController: SVNFormDisclosureButtonDelegate {
  func onDisclosureButtonTap(alertViewPresentationData data: SVNFormTermsOverlayDataSource?) {
    view.endEditing(true)
    guard let tooltipData = data else { return }
    delegate.forwardingOnToolTipTap(withData: tooltipData)
  }
}


extension SVNFormViewController: SVNFormViewModelDelegate {
  func formWasValidated() {
    
    delegate.formWasValidated(withText: formFields.map({
      switch $0.type! {
      case .textField:
        return $0.textField.validationText
        
      case .checkMark:
        return $0.checkMarkView.validationText
        
      case .toggle:
        return $0.toggleView.validationText
      }
    }))
  }
  
  
  func formWasInvalid(error: [(Validatable, ValidationError)]) {
    for (index, field) in formFields.enumerated() {
      if let _ = error.filter({ ($0.1.field as? UIView)?.superview == field }).first { // if is errored scroll to it
        scrollView.setContentOffset(CGPoint(x: 0, y: formFields[index].frame.origin.y - SVNFormViewModel.FieldYpadding), animated: true)
        return // then end
      }
    }
    delegate.notifyUserOfFailedValidation()
  }
  
  func fieldWasValidated(field: SVNFormField) {
    delegate.fieldWasValidated(field: field)
  }
}


extension SVNFormViewController: UIScrollViewDelegate {
  //MARK: ScrollView Delegate
  
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    delegate.scrollViewContentOffset(isZero: scrollView.contentOffset == CGPoint.zero)
  }
}

