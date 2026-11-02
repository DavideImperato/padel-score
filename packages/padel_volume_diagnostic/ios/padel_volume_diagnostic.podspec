Pod::Spec.new do |s|
  s.name             = 'padel_volume_diagnostic'
  s.version          = '0.0.1'
  s.summary          = 'Debug-only iOS volume read/write diagnostic.'
  s.description      = <<-DESC
A local iOS diagnostic for measuring MPVolumeView write confirmations.
DESC
  s.homepage         = 'https://localhost.invalid/padel-volume-diagnostic'
  s.license          = { :type => 'MIT', :text => 'Internal diagnostic only' }
  s.author           = { 'Padel Score Board' => 'local@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.frameworks       = 'AVFoundation', 'MediaPlayer', 'UIKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
