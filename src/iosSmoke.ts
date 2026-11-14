// Invoked only by the simulator's LX_IOS_SMOKE launch environment.
import RNFS from 'react-native-fs'
import { Buffer } from '@craftzdog/react-native-buffer'
import { NativeModules } from 'react-native'
import TrackPlayer from '@/plugins/player/trackPlayer'
import { initial } from '@/plugins/player'
import { loadScript, onScriptAction, sendAction, destroy } from '@/utils/nativeModules/userApi'
import { gzipFile, unGzipFile, readFile, writeFile } from '@/utils/fs'
import { getBootLog } from '@/utils/bootLog'

const pause = async(ms: number) => new Promise<void>(resolve => setTimeout(resolve, ms))
const assert = (condition: unknown, message: string) => { if (!condition) throw new Error(message) }

const testUserSource = async() => new Promise<void>((resolve, reject) => {
  const timeout = setTimeout(() => { finish(new Error('JavaScriptCore user source timed out')) }, 10_000)
  let unsubscribe: () => void = () => {}
  const finish = (error?: Error) => {
    clearTimeout(timeout)
    unsubscribe()
    destroy()
    if (error) reject(error)
    else resolve()
  }
  unsubscribe = onScriptAction(event => {
    if (event.action === 'init') {
      if (!event.data.status) { finish(new Error(event.data.errorMessage)); return }
      const fixture: LX.Music.MusicInfo = {
        id: 'ios-fixture',
        name: 'Fixture',
        singer: 'CI',
        source: 'kw',
        interval: null,
        meta: { songId: '1', albumName: '', qualitys: [], _qualitys: {} },
      }
      const request: LX.UserApi.UserApiRequestParams = {
        requestKey: 'ios-smoke',
        data: { source: 'kw', action: 'musicUrl', info: { type: '128k', musicInfo: fixture } },
      }
      sendAction('request', request)
    } else if (event.action === 'response' && event.data.requestKey === 'ios-smoke') {
      if (!event.data.status || event.data.result?.data.url !== 'https://example.invalid/ios-fixture.mp3') {
        finish(new Error(event.data.errorMessage ?? 'Unexpected custom-source response'))
      } else finish()
    }
  })
  loadScript({
    id: 'ios-smoke',
    name: 'Built-in CI fixture',
    description: '',
    author: '',
    version: '1',
    homepage: '',
    allowShowUpdateAlert: false,
    script: `
      lx.on(lx.EVENT_NAMES.request, () => new Promise(resolve => setTimeout(() => resolve('https://example.invalid/ios-fixture.mp3'), 10)));
      lx.send(lx.EVENT_NAMES.inited, { sources: { kw: { type: 'music', actions: ['musicUrl'], qualitys: ['128k'] } } });
    `,
  })
})

export const runSmokeTests = async() => {
  const checks: string[] = ['home screen initialized']
  const reportPath = RNFS.CachesDirectoryPath + '/lx-ios-smoke.json'
  try {
    const crypto = NativeModules.CryptoModule
    const text = 'Hello iPhone 你好'
    const input = Buffer.from(text).toString('base64')
    const key = Buffer.from('0123456789abcdef').toString('base64')
    const encrypted = crypto.aesEncryptSync(input, key, key, 'AES/CBC/PKCS7Padding')
    assert(crypto.aesDecryptSync(encrypted, key, key, 'AES/CBC/PKCS7Padding') === text, 'Native AES round-trip failed')
    const pair = await crypto.generateRsaKey()
    const cipher = await crypto.rsaEncrypt(input, pair.publicKey, 'RSA/ECB/OAEPWithSHA1AndMGF1Padding')
    assert(await crypto.rsaDecrypt(cipher, pair.privateKey, 'RSA/ECB/OAEPWithSHA1AndMGF1Padding') === text, 'Native RSA round-trip failed')
    checks.push('native AES/RSA bridge')

    const path = RNFS.CachesDirectoryPath + '/ios-smoke-fixture'
    await writeFile(path, text)
    await gzipFile(path, path + '.gz')
    await unGzipFile(path + '.gz', path + '.txt')
    assert(await readFile(path + '.txt') === text, 'File gzip round-trip failed')
    checks.push('sandbox files and gzip')

    await testUserSource()
    checks.push('JavaScriptCore source initialization, timer and request-response bridge')

    const sampleRate = 16000
    const dataSize = sampleRate * 3 * 2
    const wave = Buffer.alloc(44 + dataSize)
    wave.write('RIFF', 0); wave.writeUInt32LE(36 + dataSize, 4); wave.write('WAVEfmt ', 8)
    wave.writeUInt32LE(16, 16); wave.writeUInt16LE(1, 20); wave.writeUInt16LE(1, 22)
    wave.writeUInt32LE(sampleRate, 24); wave.writeUInt32LE(sampleRate * 2, 28)
    wave.writeUInt16LE(2, 32); wave.writeUInt16LE(16, 34); wave.write('data', 36); wave.writeUInt32LE(dataSize, 40)
    const audioPath = RNFS.CachesDirectoryPath + '/ios-smoke.wav'
    await RNFS.writeFile(audioPath, wave.toString('base64'), 'base64')
    await initial({ volume: 0, playRate: 1, cacheSize: 0, isHandleAudioFocus: true, isEnableAudioOffload: false })
    await TrackPlayer.add({ id: 'ios-smoke', url: 'file://' + audioPath, title: 'Local test fixture', artist: 'CI' })
    await TrackPlayer.play()
    for (let attempt = 0; attempt < 25 && await TrackPlayer.getPosition() < 0.2; attempt++) await pause(200)
    const position = await TrackPlayer.getPosition()
    const duration = await TrackPlayer.getDuration()
    assert(position > 0.1 && duration >= 2.9 && duration <= 3.1, `Unexpected AVPlayer times: ${position}/${duration}`)
    await TrackPlayer.pause()
    await TrackPlayer.seekTo(1)
    await pause(300)
    assert(Math.abs(await TrackPlayer.getPosition() - 1) < 0.25, 'AVPlayer seek failed')
    await TrackPlayer.reset()
    checks.push('AVPlayer local playback, seconds, pause and seek')
    await RNFS.writeFile(reportPath, JSON.stringify({ status: 'passed', checks, boot: getBootLog() }))
  } catch (error: any) {
    await RNFS.writeFile(reportPath, JSON.stringify({ status: 'failed', checks, error: error.stack ?? error.message, boot: getBootLog() }))
  }
}
