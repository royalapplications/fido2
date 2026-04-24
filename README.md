# FIDO2

Contains scripts to build a macOS-universal static library of libfido2. Also packages it into an XCFramework for easy consumption with Swift packages or Xcode.

libfido2's Apple backend uses macOS IOKit HID APIs, so this wrapper intentionally does not build iOS device or simulator slices.

Release names refer to the libfido2, libcbor, and OpenSSL versions used during compilation.
