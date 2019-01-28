Pod::Spec.new do |s|
s.name = 'AwesomeAudio'
s.version = '0.1.2'
s.summary = 'Light weight audio player built on top of AVFoundation'
s.description = <<-DESC
Light weight audio player built using AVPlayer and AVPlayerItem of AVFoundation.
DESC
s.homepage = 'https://github.com/ihak/AwesomeAudio'
s.license = { :type => 'MIT', :file => 'LICENSE' }
s.author = { 'Hassan Ahmed Khan' => 'hassandotahmed@gmail.com' }
s.source = { :git => 'https://github.com/ihak/AwesomeAudio.git', :tag => s.version.to_s }
s.social_media_url = 'https://twitter.com/hassandotahmed'
s.ios.deployment_target = '12.1'
s.source_files = 'AwesomeAudio/**/*.{swift}'
s.swift_version = "4.2"
end
