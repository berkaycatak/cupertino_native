import Flutter
import UIKit

/// A `UIAlertController` that completely manages its own background dimming
/// to fix the iOS tint adjustment bug
class TintAdjustingAlertController: UIAlertController {
    private var backgroundDimmingView: UIView?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Disable automatic tint adjustment entirely
        if let presentingVC = presentingViewController {
            presentingVC.view.tintAdjustmentMode = .normal
            if let navController = presentingVC as? UINavigationController {
                navController.navigationBar.tintAdjustmentMode = .normal
                navController.viewControllers.forEach { $0.view.tintAdjustmentMode = .normal }
            }
        }
        
        // Add our own dimming view
        addCustomDimmingView()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Remove custom dimming and restore normal tint
        removeCustomDimmingView()
        
        // Force all views to normal tint mode
        if let presentingVC = presentingViewController {
            presentingVC.view.tintAdjustmentMode = .automatic
            if let navController = presentingVC as? UINavigationController {
                navController.navigationBar.tintAdjustmentMode = .automatic
                navController.viewControllers.forEach { $0.view.tintAdjustmentMode = .automatic }
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Final cleanup
        removeCustomDimmingView()
    }
    
    private func addCustomDimmingView() {
        guard let presentingVC = presentingViewController,
              backgroundDimmingView == nil else { return }
        
        let dimmingView = UIView()
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dimmingView.frame = presentingVC.view.bounds
        dimmingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimmingView.alpha = 0
        
        presentingVC.view.insertSubview(dimmingView, belowSubview: view)
        backgroundDimmingView = dimmingView
        
        UIView.animate(withDuration: 0.3) {
            dimmingView.alpha = 1
        }
    }
    
    private func removeCustomDimmingView() {
        guard let dimmingView = backgroundDimmingView else { return }
        
        UIView.animate(withDuration: 0.3, animations: {
            dimmingView.alpha = 0
        }) { _ in
            dimmingView.removeFromSuperview()
        }
        
        backgroundDimmingView = nil
    }
}

class CupertinoAlertDialogPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private var alertController: TintAdjustingAlertController?
  private var alertStyle: String = "glass"
  
  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeAlertDialog_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    
    var title: String = ""
    var message: String? = nil
    var actionTitles: [String] = []
    var actionStyles: [String] = []
    var actionEnabled: [Bool] = []
    var iconName: String? = nil
    var iconSize: CGFloat? = nil
    var iconColor: UIColor? = nil
    var iconMode: String? = nil
    var iconPalette: [UIColor] = []
    var iconGradient: Bool = false
    var isDark: Bool = false
    var tint: UIColor? = nil
    var alertStyleParam: String = "glass"
    
    if let dict = args as? [String: Any] {
      if let t = dict["title"] as? String { title = t }
      if let m = dict["message"] as? String { message = m }
      if let at = dict["actionTitles"] as? [String] { actionTitles = at }
      if let ast = dict["actionStyles"] as? [String] { actionStyles = ast }
      if let ae = dict["actionEnabled"] as? [Bool] { actionEnabled = ae }
      if let iconNameValue = dict["iconName"] as? String { iconName = iconNameValue }
      if let iconSizeValue = dict["iconSize"] as? NSNumber { iconSize = CGFloat(truncating: iconSizeValue) }
      if let ic = dict["iconColor"] as? NSNumber { iconColor = Self.colorFromARGB(ic.intValue) }
      if let im = dict["iconRenderingMode"] as? String { iconMode = im }
      if let ip = dict["iconPaletteColors"] as? [NSNumber] { 
        iconPalette = ip.map { Self.colorFromARGB($0.intValue) }
      }
      if let ig = dict["iconGradientEnabled"] as? Bool { iconGradient = ig }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any], let n = style["tint"] as? NSNumber { 
        tint = Self.colorFromARGB(n.intValue) 
      }
      if let alertStyleValue = dict["alertStyle"] as? String { alertStyleParam = alertStyleValue }
    }
    
    self.alertStyle = alertStyleParam
    
    super.init()
    
    setupAlert(title: title, message: message, actionTitles: actionTitles, 
               actionStyles: actionStyles, actionEnabled: actionEnabled,
               iconName: iconName, iconSize: iconSize, iconColor: iconColor,
               iconMode: iconMode, iconPalette: iconPalette, iconGradient: iconGradient,
               isDark: isDark, tint: tint)
    
    self.channel.setMethodCallHandler(onMethodCall)
  }
  
  func view() -> UIView {
    return container
  }
  
  private func setupAlert(title: String, message: String?, actionTitles: [String],
                         actionStyles: [String], actionEnabled: [Bool],
                         iconName: String?, iconSize: CGFloat?, iconColor: UIColor?,
                         iconMode: String?, iconPalette: [UIColor], iconGradient: Bool,
                         isDark: Bool, tint: UIColor?) {
    
    // Create TintAdjustingAlertController instead of UIAlertController
    alertController = TintAdjustingAlertController(title: title, message: message, preferredStyle: .alert)
    
    guard let alert = alertController else { return }
    
    // Apply liquid glass styling if available (iOS 15+)
    if #available(iOS 15.0, *) {
      // Apply glass effect and modern styling
      switch alertStyle {
      case "glass", "prominentGlass":
        // Configure background with authentic iOS corner radius
        // iOS alerts use 13pt corner radius with continuous curve
        alert.view.layer.cornerRadius = 28.0
        alert.view.layer.cornerCurve = .continuous
        
        // Add subtle shadow for depth
        // alert.view.layer.shadowColor = UIColor.black.cgColor
        alert.view.layer.shadowOpacity = 0.1
        alert.view.layer.shadowOffset = CGSize(width: 0, height: 2)
        alert.view.layer.shadowRadius = 10
        
        // Ensure proper masking
        alert.view.layer.masksToBounds = false
        
        // Add glass effect with proper iOS materials
        if #available(iOS 15.0, *) {
          // Use systemThinMaterial for more authentic iOS look
          let blurEffect = UIBlurEffect(style: isDark ? .systemThinMaterialDark : .systemThinMaterialLight)
          let blurView = UIVisualEffectView(effect: blurEffect)
          blurView.frame = alert.view.bounds
          blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alert.view.layer.cornerRadius = 28.0
          blurView.layer.cornerCurve = .continuous
          blurView.clipsToBounds = true
          
          // Insert blur view behind content
          alert.view.insertSubview(blurView, at: 0)
          
          // Make the alert background transparent to show blur
          alert.view.backgroundColor = UIColor.clear
        } else {
          // Fallback for older iOS versions
          alert.view.backgroundColor = isDark ? 
            UIColor.systemBackground.withAlphaComponent(0.9) : 
            UIColor.systemBackground.withAlphaComponent(0.95)
        }
        
        // Apply tint if available
        if let tintColor = tint {
          alert.view.tintColor = tintColor
        }
        
      default:
        break
      }
    }
    
    // Add icon if provided - create custom view with icon and message
    if let iconName = iconName, let image = UIImage(systemName: iconName) {
      var finalImage = image
      
      // Apply size
      if let size = iconSize {
        let config = UIImage.SymbolConfiguration(pointSize: size)
        finalImage = finalImage.withConfiguration(config)
      }
      
      // Apply color and rendering mode
      if let color = iconColor {
        finalImage = finalImage.withTintColor(color, renderingMode: .alwaysOriginal)
      }
      
      // Apply rendering mode
      if let mode = iconMode {
        switch mode {
        case "template":
          finalImage = finalImage.withRenderingMode(.alwaysTemplate)
        case "original":
          finalImage = finalImage.withRenderingMode(.alwaysOriginal)
        case "hierarchical":
          if #available(iOS 15.0, *) {
            let config = UIImage.SymbolConfiguration(hierarchicalColor: iconColor ?? .label)
            finalImage = finalImage.withConfiguration(config)
          }
        case "palette":
          if #available(iOS 15.0, *), !iconPalette.isEmpty {
            let config = UIImage.SymbolConfiguration(paletteColors: iconPalette)
            finalImage = finalImage.withConfiguration(config)
          }
        case "multicolor":
          if #available(iOS 15.0, *) {
            let config = UIImage.SymbolConfiguration.preferringMulticolor()
            finalImage = finalImage.withConfiguration(config)
          }
        default:
          break
        }
      }
      
      // Create a custom content view controller
      let contentViewController = UIViewController()
      
      // Create image view for icon
      let imageView = UIImageView(image: finalImage)
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.contentMode = .scaleAspectFit
      contentViewController.view.addSubview(imageView)
      
      // Create label for message if we have one
      if let messageText = message, !messageText.isEmpty {
        let messageLabel = UILabel()
        messageLabel.text = messageText
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 13)
        messageLabel.textColor = .secondaryLabel
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentViewController.view.addSubview(messageLabel)
        
        // Layout: icon on top, message below
        NSLayoutConstraint.activate([
          // Icon constraints
          imageView.topAnchor.constraint(equalTo: contentViewController.view.topAnchor, constant: 8),
          imageView.centerXAnchor.constraint(equalTo: contentViewController.view.centerXAnchor),
          imageView.widthAnchor.constraint(equalToConstant: iconSize ?? 24),
          imageView.heightAnchor.constraint(equalToConstant: iconSize ?? 24),
          
          // Message constraints
          messageLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
          messageLabel.leadingAnchor.constraint(equalTo: contentViewController.view.leadingAnchor, constant: 16),
          messageLabel.trailingAnchor.constraint(equalTo: contentViewController.view.trailingAnchor, constant: -16),
          messageLabel.bottomAnchor.constraint(equalTo: contentViewController.view.bottomAnchor, constant: -8),
          
          // Container width and height
          contentViewController.view.widthAnchor.constraint(equalToConstant: 250),
          contentViewController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
        
        // Clear the original message since we're showing it in our custom view
        alert.message = nil
      } else {
        // No message, just center the icon
        NSLayoutConstraint.activate([
          imageView.centerXAnchor.constraint(equalTo: contentViewController.view.centerXAnchor),
          imageView.centerYAnchor.constraint(equalTo: contentViewController.view.centerYAnchor),
          imageView.widthAnchor.constraint(equalToConstant: iconSize ?? 24),
          imageView.heightAnchor.constraint(equalToConstant: iconSize ?? 24),
          
          contentViewController.view.widthAnchor.constraint(equalToConstant: 250),
          contentViewController.view.heightAnchor.constraint(equalToConstant: 60)
        ])
      }
      
      // Set the custom view controller as the content
      alert.setValue(contentViewController, forKey: "contentViewController")
    }
    
    // Add actions
    for (index, actionTitle) in actionTitles.enumerated() {
      let style = index < actionStyles.count ? actionStyles[index] : "defaultAction"
      let enabled = index < actionEnabled.count ? actionEnabled[index] : true
      
      // Detect dark mode
      let isDarkMode: Bool
      if #available(iOS 13.0, *) {
        isDarkMode = alert.traitCollection.userInterfaceStyle == .dark
      } else {
        isDarkMode = false
      }
      
      let alertActionStyle: UIAlertAction.Style
      var titleText = actionTitle
      var textColor: UIColor?
      var textFont: UIFont?
      
      switch style {
      case "cancel":
        alertActionStyle = .cancel
        textColor = isDarkMode ? UIColor.systemRed.withAlphaComponent(0.9) : .systemRed
      case "destructive":
        alertActionStyle = .destructive
      case "primary":
        alertActionStyle = .default
        textColor = isDarkMode ? UIColor.systemBlue.withAlphaComponent(0.9) : .systemBlue
        textFont = .boldSystemFont(ofSize: 17)
      case "secondary":
        alertActionStyle = .default
        textColor = isDarkMode ? UIColor.secondaryLabel.withAlphaComponent(0.8) : .secondaryLabel
      case "success":
        alertActionStyle = .default
        textColor = isDarkMode ? UIColor.systemGreen.withAlphaComponent(0.9) : .systemGreen
      case "warning":
        alertActionStyle = .default
        textColor = isDarkMode ? UIColor.systemOrange.withAlphaComponent(0.9) : .systemOrange
      case "info":
        alertActionStyle = .default
        textColor = isDarkMode ? UIColor.systemBlue.withAlphaComponent(0.8) : .systemBlue
      case "disabled":
        alertActionStyle = .default
        textColor = isDarkMode ? UIColor.tertiaryLabel.withAlphaComponent(0.6) : .tertiaryLabel
      default:
        alertActionStyle = .default
      }
      
      let action = UIAlertAction(title: titleText, style: alertActionStyle) { [weak self] _ in
        // Send the action callback
        self?.channel.invokeMethod("actionPressed", arguments: ["index": index])
      }
      
      // Apply custom colors safely using attributed title
      if let color = textColor, style != "destructive" {
        do {
          let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: textFont ?? UIFont.systemFont(ofSize: 17)
          ]
          let attributedTitle = NSAttributedString(string: titleText, attributes: attributes)
          
          // Use safer key-value coding approach
          if action.responds(to: Selector(("_setTitleTextColor:"))) {
            action.setValue(color, forKey: "_titleTextColor")
          }
          
          // Alternative: Try setting attributed title
          if action.responds(to: Selector(("setAttributedTitle:"))) {
            action.setValue(attributedTitle, forKey: "attributedTitle")
          }
        } catch {
          // If styling fails, continue without it - no crash
          print("Alert action styling failed safely")
        }
      }
      
      action.isEnabled = enabled && style != "disabled"
      alert.addAction(action)
    }
    
    // Present the alert
    DispatchQueue.main.async { [weak self] in
      if let topController = self?.topViewController() {
        topController.present(alert, animated: true)
      }
    }
  }
  
  private func topViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else {
      return nil
    }
    
    var topController = window.rootViewController
    while let presentedController = topController?.presentedViewController {
      topController = presentedController
    }
    return topController
  }
  
  private func onMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setBrightness":
      if let args = call.arguments as? [String: Any],
         let isDark = args["isDark"] as? Bool {
        updateBrightness(isDark: isDark)
      }
      result(nil)
      
    case "setStyle":
      if let args = call.arguments as? [String: Any],
         let tint = args["tint"] as? NSNumber {
        updateStyle(tint: Self.colorFromARGB(tint.intValue))
      }
      result(nil)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func updateBrightness(isDark: Bool) {
    guard let alert = alertController else { return }
    
    if #available(iOS 15.0, *) {
      // Update blur effect for glass style
      if alertStyle == "glass" || alertStyle == "prominentGlass" {
        let blurEffect = UIBlurEffect(style: isDark ? .systemThinMaterialDark : .systemThinMaterialLight)
        
        // Find and update the blur view
        for subview in alert.view.subviews {
          if let blurView = subview as? UIVisualEffectView {
            blurView.effect = blurEffect
            break
          }
        }
      }
    }
  }
  
  private func updateStyle(tint: UIColor) {
    guard let alert = alertController else { return }
    alert.view.tintColor = tint
  }
  
  static func colorFromARGB(_ argb: Int) -> UIColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return UIColor(red: r, green: g, blue: b, alpha: a)
  }
}