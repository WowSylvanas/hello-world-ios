import { Alert } from 'react-native'

// iOS does not allow Android-style lyric overlays above other apps.
export const showDesktopLyricView = async(_options: unknown) => {
  Alert.alert('桌面歌词', 'iOS 不支持跨应用悬浮歌词，请在应用的播放详情页查看歌词。')
}
export const setSendLyricTextEvent = async(_enabled: boolean) => {}
export const hideDesktopLyricView = async() => {}
export const play = async(_time: number) => {}
export const pause = async() => {}
export const setLyric = async(_lyric: string, _translation: string, _roma: string) => {}
export const setPlaybackRate = async(_rate: number) => {}
export const toggleTranslation = async(_enabled: boolean) => {}
export const toggleRoma = async(_enabled: boolean) => {}
export const toggleLock = async(_enabled: boolean) => {}
export const setColor = async(_unplayed: string, _played: string, _shadow: string) => {}
export const setAlpha = async(_value: number) => {}
export const setTextSize = async(_value: number) => {}
export const setShowToggleAnima = async(_enabled: boolean) => {}
export const setSingleLine = async(_enabled: boolean) => {}
export const setPosition = async(_x: number, _y: number) => {}
export const setMaxLineNum = async(_value: number) => {}
export const setWidth = async(_value: number) => {}
export const setLyricTextPosition = async(_x: string, _y: string) => {}
export const checkOverlayPermission = async() => {}
export const openOverlayPermissionActivity = async() => {
  Alert.alert('桌面歌词', 'iOS 没有 Android 的悬浮窗权限。')
}
export const onPositionChange = (_handler: (position: { x: number, y: number }) => void) => () => {}
export const onLyricLinePlay = (_handler: (info: { text: string, extendedLyrics: string[] }) => void) => () => {}
