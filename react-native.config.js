module.exports = {
  dependencies: {
    // These forks contain Android implementations only. iOS uses RNFS and LXIOS.
    'react-native-file-system': { platforms: { ios: null } },
    'react-native-local-media-metadata': { platforms: { ios: null } },
  },
}
