Pod::Spec.new do |s|
  s.name             = 'FynoTOTP'
  s.version          = '1.0.1'
  s.summary          = 'Fyno TOTP SDK for iOS – Simple, secure, multi-tenant TOTP generation.'
  s.description      = <<-DESC
    FynoTOTP is a lightweight, secure TOTP generation SDK built for iOS.
    Supports multi-tenant TOTPs, search, swipe-to-delete, and integrates easily 
    with SwiftUI or UIKit applications.
  DESC

  s.homepage         = 'https://github.com/fynoio/ios-totp'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Fyno' => 'tech@fyno.io' }
  s.social_media_url = 'https://twitter.com/fyno_io'

  # Replace with your actual source repo
  s.source           = { 
    :git => 'https://github.com/fynoio/ios-totp.git',
    :tag => s.version 
  }

  # Platform
  s.platform     = :ios, '13.0'
  s.swift_version = '6.2'

  # Source Files
  s.source_files = 'Sources/FynoTOTP/**/*.{swift}'

  s.dependency "FMDB", "~> 2.7.5"

  # Frameworks
  s.framework = 'Foundation'
end
