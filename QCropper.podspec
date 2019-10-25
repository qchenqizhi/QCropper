#
# Be sure to run `pod lib lint QCropper.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'QCropper'
  s.version          = '0.1.0'
  s.summary          = 'Image cropping/rotating/straightening library for iOS in Swift.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Image cropping/rotating/straightening library for iOS in Swift
                       DESC

  s.homepage         = 'https://github.com/qchenqizhi/QCropper'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Chen' => 'qchenqizhi@gmail.com' }
  s.source           = { :git => 'https://github.com/qchenqizhi/QCropper.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'

  s.source_files = 'QCropper/**/*'
  s.resources = ["Assets/*.png"]
  # s.resource_bundles = {
  #   'QCropper' => ['Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
