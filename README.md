# SwiftUI Hello World：Windows 免费安装到 iPhone

这是一个最小的原生 SwiftUI iPhone App：打开后在屏幕中央显示 `Hello, World!`，桌面图标为蓝底白色 H。

- 最低系统：iOS 16.0；仅针对 iPhone。
- 不使用 Expo、CocoaPods、第三方 Swift 库或外部服务。
- Windows 负责编辑、上传和安装，GitHub Actions 的云端 Mac 负责编译。
- 云端生成 **未签名的真机 IPA**，再由 Windows 上的 Sideloadly 使用你的免费 Apple 账号签名并安装。
- 不需要苹果开发者年费，不需要越狱；免费签名通常 **7 天到期**，到期前需续签。

## 1. 准备工具和账号

1. 注册或登录 [GitHub](https://github.com/)。
2. 确认 Windows 已安装 [Git for Windows](https://git-scm.com/downloads/win)。在 PowerShell 中运行 `git --version` 可检查。
3. 准备一个可以正常登录并接收验证的免费 Apple 账号。
4. 从 [Sideloadly 官网](https://sideloadly.io/)下载并安装 Windows 版。其当前安装说明要求 Windows 上有网页安装版 iTunes、iCloud 等组件，请以官网的最新要求和下载入口为准。
5. 准备能传输数据的数据线，以及一台 iOS 16.0 或更新系统的 iPhone。

不要把 Apple 密码、验证码、证书或 GitHub 访问令牌写进代码、工作流或 GitHub Secrets。此工作流不需要任何 Secrets；Apple 账号验证只在本地 Sideloadly 安装时进行。

## 2. 在 GitHub 创建仓库

1. 登录 GitHub，点击右上角 `+` → `New repository`，也可以打开 <https://github.com/new>。
2. Repository name 填写 `hello-world-ios`。
3. 为了使用公开仓库标准托管运行器的免费计算资源，选择 **Public**。公开后，其他人可以看到这里的源代码。私有仓库也能构建，但会消耗账号的免费计算额度。
4. **不要**勾选生成 README、`.gitignore` 或 License，保持远端仓库为空。
5. 点击 `Create repository`，记下仓库的 HTTPS 地址，例如 `https://github.com/YOUR_USERNAME/hello-world-ios.git`。

公开仓库标准托管运行器的计算使用免费；产物存储仍受额度限制。本工作流将 IPA 保留 7 天、日志保留 3 天。规则见 [GitHub Actions 计费文档](https://docs.github.com/en/billing/concepts/product-billing/github-actions)。

## 3. 从当前目录上传

在 PowerShell 中进入本项目目录，然后逐行执行：

```powershell
Set-Location -LiteralPath 'D:\IntegratedProject\IOS开发'
git init -b main
git add .
git commit -m "Create SwiftUI Hello World and unsigned IPA workflow"
```

如果 `git commit` 提示没有配置身份，先在这个仓库内设置，然后重新执行 `git commit`。将以下示例替换成你的名称和邮箱，也可以使用 GitHub 设置中的隐私邮箱：

```powershell
git config user.name "你的名称"
git config user.email "你的邮箱"
git commit -m "Create SwiftUI Hello World and unsigned IPA workflow"
```

将下面的 `YOUR_USERNAME` 替换为你的 GitHub 用户名，再执行：

```powershell
git remote add origin https://github.com/YOUR_USERNAME/hello-world-ios.git
git push -u origin main
```

如果 Git 弹出登录窗口，按提示在浏览器授权。HTTPS 推送不使用 GitHub 网站登录密码作为 Git 密码；通常 Git for Windows 的凭据管理器会处理浏览器登录。

务必保留并上传 `.github/workflows/build-ios.yml`。上面的 `git add .` 会包含它，不要只上传 `HelloWorld` 文件夹。

## 4. 运行编译并下载 IPA

推送到 `main` 后会自动构建。也可以手动触发：

1. 打开 GitHub 仓库 → `Actions`。
2. 如果 GitHub 提示启用 Actions，先启用。
3. 左侧点击 **Build unsigned iOS IPA**。
4. 点击 `Run workflow`，分支选择 `main`，确认运行。
5. 等待本次运行出现绿色勾。首次编译通常需要几分钟，具体取决于 GitHub 排队和构建情况。
6. 打开这次运行的详情页，在页面下方 **Artifacts** 中下载 **HelloWorld-unsigned-ipa**。
7. 将下载的 ZIP 解压，得到：

   ```text
   HelloWorld-unsigned.ipa
   HelloWorld-unsigned.ipa.sha256
   ```

要交给 Sideloadly 的文件是 **`.ipa`**，不是 GitHub 下载的外层 ZIP。不要解压 IPA 本身，也不要将 ZIP 直接改名成 IPA。

这个 IPA 内部为 `Payload/HelloWorld.app`，其中包含面向真机的 arm64 可执行文件。构建过程会检查产物的平台、架构和 ZIP 完整性，并生成 SHA-256 文件。`.ipa` 仍然未签名，无法直接在 Safari 或“文件”App 中点击安装。

GitHub 上的 `HelloWorld-build-log` 是编译日志。如果工作流失败，打开红色失败步骤查看日志；不要把失败运行当成已生成可安装 IPA。

## 5. 用 Sideloadly 安装到 iPhone

1. 用数据线连接 Windows 和 iPhone。解锁 iPhone，在“信任此电脑”提示中选择信任并输入手机密码。
2. 打开 Sideloadly，在设备列表中选择你的 iPhone。
3. 把 `HelloWorld-unsigned.ipa` 拖到 Sideloadly 的 IPA 区域。
4. 在 Apple Account / Apple ID 栏输入你的免费 Apple 账号。
5. 使用普通的 **Apple ID Sideload** 安装模式，点击 `Start`，在本地工具中按提示输入密码、完成验证。
6. 根据手机提示，在 `设置 → 通用 → VPN 与设备管理` 中找到你的开发者账号并信任。如果没有这项提示，则继续下一步。
7. 在 `设置 → 隐私与安全性 → 开发者模式` 中启用开发者模式，按提示重启，并在重启后再次确认开启。这个选项有时要在首次安装或设备配对之后才出现；若看不到，先完成 Sideloadly 安装，并查看其当前提示和 [FAQ](https://sideloadly.io/faq.html)。
8. 在 iPhone 主屏幕或 App 资源库找到 **HelloWorld**（蓝底白 H 图标），点击打开，应该看到 **Hello, World!**。

这是独立的原生 App；安装和信任完成后，在签名有效期内可以断开电脑、离线使用。安装过程仍可能受 Apple 账号、iOS 版本和 Sideloadly 当前兼容性影响，发生错误时以工具日志为准。

## 6. 7 天续签

- 免费账号签名通常有效 7 天，到期后 App 将不能打开，需重新签名安装。
- 保留 `HelloWorld-unsigned.ipa`，不必每周重新编译。用同一个 Apple 账号和相同的 Bundle ID，通过 Sideloadly 覆盖安装即可；尽量不要先卸载。
- 可以在 Sideloadly 开启自动刷新。自动刷新需要电脑运行 Sideloadly 后台程序，并通过 USB 连接手机，或提前配置 Wi-Fi 安装并让手机与电脑处于可互通的同一网络。电脑关机时不会自动续签。
- 免费账号通常最多同时安装 3 个此类 App，并有 App ID 等额外限制。这里的 HelloWorld 只占 1 个。
- 不需要启用 JIT，也不需要购买企业签名。

限制及自动刷新条件见 [Sideloadly FAQ](https://sideloadly.io/faq.html) 和 [苹果免费 Personal Team 说明](https://developer.apple.com/help/account/basics/about-your-developer-account)。

## 7. 修改文字后重新构建

编辑 `HelloWorld/ContentView.swift` 中的这一行：

```swift
Text("Hello, World!")
```

例如改成 `Text("你好，iPhone！")`，保存后执行：

```powershell
git add HelloWorld/ContentView.swift
git commit -m "Update greeting"
git push
```

随后从新运行的 Artifacts 下载新 IPA，并使用相同 Apple 账号覆盖安装。

工程默认 Bundle ID 为 `com.example.szy.helloworld`。若签名时提示标识冲突，可在 Sideloadly 高级选项中使用一个自己唯一的 Bundle ID，例如 `com.yourname.helloworld123`；后续续签时保持一致。也可以修改 `HelloWorld.xcodeproj/project.pbxproj` 中 Debug、Release 两处的 `PRODUCT_BUNDLE_IDENTIFIER` 后重新编译。

## 文件结构

```text
.github/workflows/build-ios.yml              云端编译、校验和上传 IPA
.gitattributes                              保持脚本和源码换行一致
.gitignore                                  排除构建产物、证书和本地文件
HelloWorld.xcodeproj/project.pbxproj         Xcode 工程
HelloWorld.xcodeproj/xcshareddata/xcschemes/
  HelloWorld.xcscheme                        云端可见的共享 Scheme
HelloWorld/HelloWorldApp.swift               App 入口
HelloWorld/ContentView.swift                 Hello World 界面
HelloWorld/Assets.xcassets/                  App 图标
README.md                                   本说明
```

## 验证范围

本地 Windows 可检查工程文件结构、Scheme、JSON、工作流和图标，但无法运行 Xcode 或 iOS 模拟器。真正的 Swift 编译、资源编译和真机 IPA 校验在 GitHub Actions 中执行；是否能在你的 iPhone 上运行，需要完成签名安装后确认。
