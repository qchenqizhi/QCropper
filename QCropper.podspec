Pod::Spec.new do |s|
  s.name             = 'QCropper'
  s.version          = '0.1.7'
  s.summary          = 'Image cropping/rotating/straightening library for iOS in Swift.'
  s.description      = <<-DESC
Image cropping/rotating/straightening library for iOS in Swift.
This project aims to provide an image cropping experience like iOS Photos.app.
                       DESC
  s.homepage         = 'https://github.com/qchenqizhi/QCropper'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Chen' => 'qchenqizhi@gmail.com' }
  s.source           = { :git => 'https://github.com/qchenqizhi/QCropper.git', :tag => s.version.to_s }
  s.swift_version = '5.0'
  s.ios.deployment_target = '11.0'
  s.source_files = 'QCropper/**/*'
  s.resources = ["Assets/*.png"]
  s.frameworks = 'UIKit'
end
