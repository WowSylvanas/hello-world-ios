# LX Music Mobile iOS 移植

这是基于上游 `0669d1b6d419967822ff52ec06e50b9613bfd136`（1.9.2）的个人测试移植分支，不是上游官方 iOS 发布。

## 构建与安装

推送 `lx-ios-port` 分支后，GitHub Actions 的 `Build LX Music iOS port` 工作流会安装依赖、编译 Release 真机版本并上传 `LXMusic-iOS-unsigned` 产物。下载 ZIP 后解压，将 `LXMusic-iOS-unsigned.ipa` 交给 Sideloadly，用自己的 Apple 账号签名安装。免费账号通常需要每 7 天续签。

开发目录：`ios/Port` 为 iOS 原生桥接，`src/utils/fs.ios.ts` 为沙盒文件系统，`src/utils/nativeModules/lyricDesktop.ios.ts` 为 iOS 平台限制提示。上游 Android 实现继续保留。

## 本分支的适配内容

- 使用 iOS 原生接口实现设备信息、语言、屏幕尺寸、保持亮屏、系统分享及缓存管理。
- 使用 RNFS 访问 App 沙盒，通过 iOS 文件选择器复制导入用户选择的文件；App Documents 支持“文件”App/iTunes 文件共享。
- 使用 CommonCrypto 与 Security 提供 AES、RSA、SHA-1 接口，保持上游的 Base64 输入和返回格式。
- 在独立 JavaScriptCore 上下文中运行上游自定义源预加载脚本，实现请求桥接、定时器和加密工具；没有内置或下载第三方音乐源。
- 音频仍由上游 TrackPlayer 的 iOS AVPlayer 实现播放，启用后台音频；兼容 Android 分支特有的播放器接口。
- 读取本地音频基本标签及封面，支持外置 LRC 歌词。
- 停用 Android APK 自更新入口，使用独立包标识 `com.wowsylvanas.lxmusic.ios`。

## 平台限制

- iOS 不支持 Android 式跨应用桌面悬浮歌词；请使用应用内播放详情页。
- 暂不提供 Android 播放器的持久音频缓存；iOS 缓存大小为 0，清理操作不删除用户文件。
- 暂不支持修改音频文件内嵌标签和封面；相关操作会返回明确错误。
- 文件夹浏览限制在 App 沙盒。系统文件选择器导入文件后，App 操作的是副本。
- iOS 自动暂停后台非音频任务。后台同步、脚本请求与定时器行为需真机验证。

## 验证

工作流成功表示依赖安装、Release 编译及 IPA 的 arm64/资源检查成功，不能代替真机测试。安装后需验证首次启动、导入兼容自定义源、搜索、播放、锁屏控制、本地文件及同步。尚未验证的功能不得视为已通过。

保留上游 README、LICENSE 和原作者声明。请使用你有权访问的音乐与音源。
