// MusicService.swift
// Audio playback service for room playlists

import Foundation
import AVFoundation
import Combine
import MediaPlayer

@MainActor
class MusicService: ObservableObject {
    static let shared = MusicService()
    
    // Playback State
    @Published var isPlaying = false
    @Published var currentTrackIndex = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    
    // Current Playlist
    @Published var currentPlaylist: [RoomTrack] = []
    @Published var currentInstanceId: String?
    
    // Download State
    @Published var downloadProgress: [String: Double] = [:] // trackUrl -> progress
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAudioSession()
        setupRemoteTransportControls()
    }
    
    // MARK: - Audio Session
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play Command
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.play()
            return .success
        }
        
        // Pause Command
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.pause()
            return .success
        }
        
        // Next Track Command
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.playNext()
            return .success
        }
        
        // Previous Track Command
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.playPrevious()
            return .success
        }
        
        // Seek Command
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: event.positionTime)
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Castle Room" // Or use room name if available context
        
        if let playerItem = playerItem {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem.duration.seconds
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Playback Control
    
    func loadPlaylist(_ playlist: [RoomTrack], instanceId: String) {
        currentPlaylist = playlist
        currentInstanceId = instanceId
        currentTrackIndex = 0
        
        if let firstTrack = playlist.first {
            loadTrack(firstTrack)
        }
    }
    
    func loadTrack(_ track: RoomTrack) {
        isLoading = true
        
        // Clean up previous player
        removeTimeObserver()
        player?.pause()
        
        // Use local file if downloaded and accessible, otherwise stream from URL
        let url: URL
        if let localUrl = resolveLocalURL(for: track) {
            url = localUrl
        } else {
            guard let remoteUrl = URL(string: track.url) else {
                isLoading = false
                return
            }
            url = remoteUrl
        }
        
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Observe when ready to play
        playerItem?.publisher(for: \.status)
            .sink { [weak self] status in
                if status == .readyToPlay {
                    self?.isLoading = false
                    self?.duration = self?.playerItem?.duration.seconds ?? 0
                }
            }
            .store(in: &cancellables)
        
        // Observe when track ends
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.playNext()
            }
            .store(in: &cancellables)
        
        setupTimeObserver()
        updateNowPlayingInfo()
    }
    
    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func stop() {
        pause()
        player?.seek(to: .zero)
        currentTime = 0
        updateNowPlayingInfo()
    }
    
    func playNext() {
        guard currentTrackIndex < currentPlaylist.count - 1 else {
            // End of playlist
            stop()
            currentTrackIndex = 0
            if let firstTrack = currentPlaylist.first {
                loadTrack(firstTrack)
            }
            return
        }
        
        currentTrackIndex += 1
        loadTrack(currentPlaylist[currentTrackIndex])
        play()
    }
    
    func playPrevious() {
        // If more than 3 seconds into track, restart. Otherwise go to previous.
        if currentTime > 3 {
            player?.seek(to: .zero)
            return
        }
        
        guard currentTrackIndex > 0 else { return }
        currentTrackIndex -= 1
        loadTrack(currentPlaylist[currentTrackIndex])
        play()
    }
    
    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 1000)) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }
    
    func playTrack(at index: Int) {
        guard index >= 0 && index < currentPlaylist.count else { return }
        currentTrackIndex = index
        loadTrack(currentPlaylist[index])
        play()
    }
    
    // MARK: - Time Observer
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    // MARK: - Download
    
    func downloadTrack(_ track: RoomTrack, folderName: String? = nil, completion: @escaping (URL?) -> Void) {
        guard let url = URL(string: track.url) else {
            completion(nil)
            return
        }
        
        downloadProgress[track.url] = 0
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationFolder: URL
        
        if let folderName = folderName {
            destinationFolder = documentsPath.appendingPathComponent(folderName)
            if !FileManager.default.fileExists(atPath: destinationFolder.path) {
                try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            }
        } else {
            destinationFolder = documentsPath
        }
        
        // Use track title for filename if possible, sanitize it
        let safeTitle = track.title.components(separatedBy: .init(charactersIn: "/\\?%*|\"<>:")).joined(separator: "_")
        let fileName = "\(safeTitle).mp3"
        let localUrl = destinationFolder.appendingPathComponent(fileName)
        
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempUrl, response, error in
            DispatchQueue.main.async {
                self?.downloadProgress.removeValue(forKey: track.url)
            }
            
            guard let tempUrl = tempUrl, error == nil else {
                completion(nil)
                return
            }
            
            do {
                if FileManager.default.fileExists(atPath: localUrl.path) {
                    try FileManager.default.removeItem(at: localUrl)
                }
                try FileManager.default.moveItem(at: tempUrl, to: localUrl)
                
                // Return relative path for storage
                let relativePath: String
                if let folderName = folderName {
                    relativePath = "\(folderName)/\(fileName)"
                } else {
                    relativePath = fileName
                }
                completion(URL(fileURLWithPath: relativePath))
            } catch {
                print("Failed to save downloaded track: \(error)")
                completion(nil)
            }
        }
        
        // Observe download progress
        task.resume()
    }
    
    func downloadPlaylist(_ playlist: [RoomTrack], roomName: String? = nil, progress: @escaping (Int, Int) -> Void, completion: @escaping ([RoomTrack]) -> Void) {
        var updatedTracks: [RoomTrack] = []
        let group = DispatchGroup()
        var completedCount = 0
        
        // Sanitize room name for folder
        let folderName = roomName?.components(separatedBy: .init(charactersIn: "/\\?%*|\"<>:")).joined(separator: "_")
        
        for track in playlist {
            group.enter()
            downloadTrack(track, folderName: folderName) { localUrl in
                var updatedTrack = track
                if let url = localUrl {
                    updatedTrack.isDownloaded = true
                    updatedTrack.localPath = url.path
                }
                updatedTracks.append(updatedTrack)
                
                DispatchQueue.main.async {
                    completedCount += 1
                    progress(completedCount, playlist.count)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(updatedTracks.sorted { $0.title < $1.title })
        }
    }
    
    // MARK: - Helpers
    
    var currentTrack: RoomTrack? {
        guard currentTrackIndex < currentPlaylist.count else { return nil }
        return currentPlaylist[currentTrackIndex]
    }
    
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    var formattedDuration: String {
        formatTime(duration)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func resolveLocalURL(for track: RoomTrack) -> URL? {
        guard track.isDownloaded, let path = track.localPath else { return nil }
        
        let fileManager = FileManager.default
        
        // 1. Check if it's an absolute path and exists (Legacy/Current session)
        if path.hasPrefix("/") {
            if fileManager.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
            // If absolute path doesn't exist, it might be due to container change
            // Try to extract relative part and fallback?
        }
        
        // 2. Treat as relative to Documents directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fullUrl = documentsPath.appendingPathComponent(path)
        
        if fileManager.fileExists(atPath: fullUrl.path) {
            return fullUrl
        }
        
        return nil
    }
}
