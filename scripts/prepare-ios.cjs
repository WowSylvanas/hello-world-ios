const fs = require('node:fs')
const path = require('node:path')
const root = path.resolve(__dirname, '..')
const copy = (from, to) => fs.copyFileSync(path.join(root, from), path.join(root, to))
copy('android/app/src/main/assets/script/user-api-preload.js', 'ios/Port/user-api-preload.js')
copy('src/resources/fonts/icomoon.ttf', 'ios/Port/icomoon.ttf')

// Repair the upstream iOS template without changing the Android project.
const projectFile = path.join(root, 'ios/LxMusicMobile.xcodeproj/project.pbxproj')
let project = fs.readFileSync(projectFile, 'utf8')
project = project.replaceAll('IPHONEOS_DEPLOYMENT_TARGET = 13.4;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;')
project = project.replaceAll('"org.reactjs.native.example.$(PRODUCT_NAME:rfc1034identifier)"', 'com.wowsylvanas.lxmusic.ios')
fs.writeFileSync(projectFile, project)
console.log('Prepared LX Music iOS resources and project settings.')
