Pod::Spec.new do |spec|

  spec.name         = "JGMethodSwizzler"
  spec.version      = "2.0.2"
  spec.summary      = "Powerful and easy to use Objective-C swizzling API."
  spec.description  = <<-DESC
An easy to use Objective-C API for swizzling class and instance methods, as well as swizzling instance methods on specific instances only.
DESC
  spec.homepage     = "https://github.com/JonasGessner/JGMethodSwizzler"
  spec.license      = { :type => "MIT", :file => "LICENSE.txt" }
  spec.author             = "Jonas Gessner"
  spec.social_media_url   = "http://twitter.com/JonasGessner"
  spec.iospec.deployment_target = '9.0'
  spec.osx.deployment_target = '10.8'
  spec.source       = { :git => "https://github.com/JonasGessner/JGMethodSwizzler.git", :tag => spec.version.to_s }
  spec.source_files  = "JGMethodSwizzler/*.{h,m}"
  spec.frameworks = "Foundation"
  spec.requires_arc = false

end
