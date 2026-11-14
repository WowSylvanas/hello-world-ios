import TrackPlayer from 'react-native-track-player'
import { NativeModules, Platform } from 'react-native'

export * from 'react-native-track-player'

// The upstream Android fork adds methods not implemented by its iOS player.
const iosPlayer = {
  ...TrackPlayer,
  // Swift removes indexes one by one; ascending indexes shift the queue and
  // can leave the silent end sentinel in the application's active-song slot.
  remove: async(tracks: number | number[]): Promise<void> => TrackPlayer.remove(
    [...new Set(Array.isArray(tracks) ? tracks : [tracks])].sort((a, b) => b - a),
  ),
  // This Android fork divides native milliseconds by 1000; AVPlayer already returns seconds.
  getPosition: async(): Promise<number> => NativeModules.TrackPlayerModule.getPosition(),
  getDuration: async(): Promise<number> => NativeModules.TrackPlayerModule.getDuration(),
  getBufferedPosition: async(): Promise<number> => NativeModules.TrackPlayerModule.getBufferedPosition(),
  isCached: async(_url: string) => false,
  getCacheSize: async() => 0,
  clearCache: async() => {},
  destroy: async() => TrackPlayer.reset(),
  updateNowPlayingMetadata: async(metadata: Record<string, unknown>, _playing?: boolean): Promise<void> => NativeModules.TrackPlayerModule.updateNowPlayingMetadata(metadata),
  updateNowPlayingTitles: async(titles: { title?: string, artist?: string, album?: string, lyric?: string }): Promise<void> => NativeModules.TrackPlayerModule.updateNowPlayingMetadata(titles),
}

export default Platform.OS === 'ios' ? iosPlayer : TrackPlayer
