import TrackPlayer, { Event } from 'react-native-track-player'
import { Platform } from 'react-native'

export * from 'react-native-track-player'

// The upstream Android fork adds methods not implemented by its iOS player.
const iosPlayer = {
  ...TrackPlayer,
  isCached: async(_url: string) => false,
  getCacheSize: async() => 0,
  clearCache: async() => {},
  destroy: async() => TrackPlayer.reset(),
  updateNowPlayingTitles: async(titles: { title?: string, artist?: string, album?: string, lyric?: string }) => TrackPlayer.updateNowPlayingMetadata(titles),
  addEventListener: ((event: string, handler: (data: any) => void) => TrackPlayer.addEventListener(event as Event, (data: any) => {
    handler(event === Event.PlaybackState && data && typeof data === 'object' ? data.state : data)
  })) as typeof TrackPlayer.addEventListener,
}

export default Platform.OS === 'ios' ? iosPlayer : TrackPlayer
