JGMethodSwizzler
==============

An easy to use Objective-C level API for swizzling class and instance methods, as well as swizzling instance methods on specific instances only.

##Documentation
The `JGMethodSwizzler.h` header file contains detailed documentation for each API call.

##Examples
The `JGMethodSwizzlerTests` Xcode Project contains several examples on how to implement `JGMethodSwizzler`.

##Notes
JGMethodSwizzlerer is built on top of <a href="http://www.cydiasubstrate.com/id/264d6581-a762-4343-9605-729ef12ff0af/">substrate</a>. You must link substrate.dylib (its done automatically in theos and iOSOpenDev) to your binary.

JGMethodSwizzler works with both ARC (automatic reference counting) and MRC (manual reference counting).

##License
Licensed under the MIT license.
