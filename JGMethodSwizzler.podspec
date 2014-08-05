Pod::Spec.new do |s|

  s.name         = "JGMethodSwizzler"
  s.version      = "2.0.1"
  s.summary      = "An easy to use Objective-C API for swizzling."
  s.description  = <<-DESC
An easy to use Objective-C API for swizzling class and instance methods, as well as swizzling instance methods on specific instances only.
DESC
  s.homepage     = "https://github.com/JonasGessner/JGMethodSwizzler"
  s.license      = { :type => "MIT", :file => "LICENSE.txt" }
  s.author             = "Jonas Gessner"
  s.social_media_url   = "http://twitter.com/JonasGessner"
  s.platform     = :ios, "5.0"
  s.source       = { :git => "https://github.com/JonasGessner/JGMethodSwizzler.git", :tag => "v2.0.1" }
  s.source_files  = "JGMethodSwizzler/*.{h,m}"
  s.frameworks = "Foundation"

end
