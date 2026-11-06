#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint bopmigo.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'bopmigo'
  s.version          = '0.0.1'
  s.summary          = 'In-app feedback for Flutter apps on iPhone and Android.'
  s.description      = <<-DESC
Know what went wrong in your Flutter app. People report it in a line, and your team gets the whole story.
                       DESC
  s.homepage         = 'https://bopmigo.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Bopmigo' => 'hello@bopmigo.com' }
  s.source           = { :path => '.' }
  s.source_files = 'bopmigo/Sources/bopmigo/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'bopmigo_privacy' => ['bopmigo/Sources/bopmigo/PrivacyInfo.xcprivacy']}
end
