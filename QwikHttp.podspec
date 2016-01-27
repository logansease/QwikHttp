#
# Be sure to run `pod lib lint QwikHttp.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "QwikHttp"
  s.version          = "0.1.0"
  s.summary          = "QwikHTTP is a simple, super powerful Http Networking library."

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
QwikHttp is based around that making HTTP networking calls to your Rest APIs should be quick,
   easy, and clean. Qwik Http allows you to send http requests and get its results back in a single line of code
   It is super, light weight- but very dynamic. It uses an inline builder style syntax to keep your code super clean.

It is written in swift and uses the most recent ios networking api, NSURLSession.

DESC
  s.homepage         = "https://github.com/qonceptual/QwikHttp"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Logan Sease" => "logansease@qonceptual.com" }
  s.source           = { :git => "https://github.com/qonceptual/QwikHttp.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'QwikHttp' => ['Pod/Assets/*.png']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end