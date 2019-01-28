//
//  AAPlayer.swift
//  AwesomeAudio
//
//  Created by Hassan Ahmed on 24/01/2019.
//  Copyright © 2019 Hassan Ahmed. All rights reserved.
//

import Foundation

import Foundation
import AVFoundation
import MediaPlayer

public class AAPlayer: NSObject {
    private var url: URL
    private var player: AVPlayer?
    private var playerItemContext = 0
    
    public var artist = "Artist"
    public var track = "Track Name | Title"
    public var artwork: UIImage?
    
    public typealias iHAKAudioPlayerHandler = (_ player: AVPlayer?, _ playerItem: AVPlayerItem?) -> Void
    private var onStatusReadyToPlay: iHAKAudioPlayerHandler?
    
    public typealias statusFailed = (_ player: AVPlayer?, _ playerItem: AVPlayerItem?, _ error: Error?) -> Void
    private var onStatusFailed: statusFailed?
    
    private var onStatusUnknown: iHAKAudioPlayerHandler?
    
    private var onProgress: iHAKAudioPlayerHandler?
    
    private var onFinishedPlayback: iHAKAudioPlayerHandler?
    
    private var onInterruptionBegin: iHAKAudioPlayerHandler?
    
    public typealias EndInterruptionHandler = (_ player: AVPlayer?, _ playerItem: AVPlayerItem?, _ shouldResume: Bool) -> Void
    private var onInterruptionEnd: EndInterruptionHandler?
    
    private var commandCenterEnabled: Bool {
        didSet {
            if commandCenterEnabled {
                let commandCenter = MPRemoteCommandCenter.shared()
                commandCenter.playCommand.isEnabled = true
                commandCenter.playCommand.addTarget(self, action: #selector(self.play))
                
                commandCenter.pauseCommand.isEnabled = true
                commandCenter.pauseCommand.addTarget(self, action: #selector(self.pause))
            }
        }
    }
    
    public var isPlaying: Bool {
        return (player!.rate > 0)
    }
    
    init(url: URL) {
        self.url = url
        self.commandCenterEnabled = false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func setup() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            self.player = AVPlayer(url: url)
            
            player?.currentItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &playerItemContext)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    public func enableCommandMediaCenter(withArtist artist: String, track: String, artwork: UIImage?) {
        commandCenterEnabled = true
        self.artist = artist
        self.track = track
        self.artwork = artwork
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            // Switch over status value
            switch status {
            case .readyToPlay:
                self.onStatusReadyToPlay?(self.player, self.player?.currentItem)
                self.addObservers()
            case .failed:
                self.onStatusFailed?(self.player, self.player?.currentItem, self.player?.currentItem?.error)
            case .unknown:
                self.onStatusUnknown?(self.player, self.player?.currentItem)
            }
        }
    }
    
    private func addObservers() {
        // Add periodic observer to track progress
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let minQueue = DispatchQueue.main
        
        _ = player?.addPeriodicTimeObserver(forInterval: interval, queue: minQueue, using: { [weak self] _ in
            self?.onProgress?(self?.player, self?.player?.currentItem)
            self?.updateMediaCenter()
        })
        
        // add audio end observer
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: OperationQueue.main) { [weak self](notification) in
            self?.player?.seek(to: .zero)
            self?.onFinishedPlayback?(self?.player, self?.player?.currentItem)
        }
        
        // add interruption observer
        notificationCenter.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            guard let userInfo = notification.userInfo,
                let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                let  type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                    return
            }
            
            if type == .began {
                self?.onInterruptionBegin?(self?.player, self?.player?.currentItem)
            }
            else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        // Interruption Ended - playback should resume
                        self?.onInterruptionEnd?(self?.player, self?.player?.currentItem, true)
                    } else {
                        // Interruption Ended - playback should NOT resume
                        self?.onInterruptionEnd?(self?.player, self?.player?.currentItem, false)
                    }
                }
            }
        }
    }
    
    @objc private func updateMediaCenter() {
        guard commandCenterEnabled else { return }
        guard let currentItem = self.player?.currentItem else { return }
        
        // Define Now Playing Info
        var nowPlayingInfo:[String: Any] =
            [MPMediaItemPropertyArtist: artist,
             MPMediaItemPropertyTitle: track,
             MPMediaItemPropertyPlaybackDuration: Float(currentItem.duration.seconds),
             MPNowPlayingInfoPropertyElapsedPlaybackTime:Float(currentItem.currentTime().seconds),
             MPNowPlayingInfoPropertyPlaybackRate: player?.rate ?? 0.0]
        
        if let image = self.artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] =
                MPMediaItemArtwork(boundsSize: image.size) { size in
                    return image
            }
        }
        
        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    @objc public func play() {
        player?.play()
        updateMediaCenter()
    }
    
    @objc public func pause() {
        player?.pause()
        updateMediaCenter()
    }
    
    public func playpause() {
        guard isPlaying else {
            play()
            return
        }
        pause()
    }
    
    public func seek(to time: CMTime) {
        player?.seek(to: time)
    }
    
    public func onStatusReadyToPlay(block: @escaping iHAKAudioPlayerHandler) {
        self.onStatusReadyToPlay = block
    }
    
    public func onStatusFailure(block: @escaping statusFailed) {
        self.onStatusFailed = block
    }
    
    public func onStatusUknown(block: @escaping iHAKAudioPlayerHandler) {
        self.onStatusUnknown = block
    }
    
    public func onProgress(block: @escaping iHAKAudioPlayerHandler) {
        self.onProgress = block
    }
    
    public func onFinishedPlayback(block: @escaping iHAKAudioPlayerHandler) {
        self.onFinishedPlayback = block
    }
    
    public func onInterruption(block: @escaping iHAKAudioPlayerHandler) {
        self.onInterruptionBegin = block
    }
    
    public func onInterruptionResume(block: @escaping EndInterruptionHandler) {
        self.onInterruptionEnd = block
    }
}
