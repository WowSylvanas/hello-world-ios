import { forwardRef, useCallback, useEffect, useId, useImperativeHandle, useMemo, useRef, useState } from 'react'
import { Animated, Keyboard, PanResponder, Pressable, StyleSheet, useWindowDimensions, View } from 'react-native'
import type { DrawerLayoutFixedProps, DrawerLayoutFixedType } from './DrawerLayoutFixed'
import { useTheme } from '@/store/theme/hook'
import { recordDrawerState } from '@/utils/iosDrawerSmoke'

export type { DrawerLayoutFixedType } from './DrawerLayoutFixed'

// DrawerLayoutAndroid is a nonfunctional placeholder on iOS. Keep the same
// ref contract for every caller using an iOS view and native-driven animation.
const DrawerLayoutFixed = forwardRef<DrawerLayoutFixedType, DrawerLayoutFixedProps>(({
  children, renderNavigationView, widthPercentage, widthPercentageMax,
  drawerPosition = 'left', drawerBackgroundColor, drawerLockMode = 'unlocked',
  style, onDrawerOpen, onDrawerClose, onDrawerStateChanged, testID,
}, ref) => {
  const theme = useTheme()
  const screen = useWindowDimensions()
  const container = useRef<View>(null)
  const [containerWidth, setContainerWidth] = useState(screen.width)
  const [isOpen, setIsOpen] = useState(drawerLockMode === 'locked-open')
  const openRef = useRef(isOpen)
  const progress = useRef(new Animated.Value(isOpen ? 1 : 0)).current
  const generatedID = useId()
  const drawerID = testID ?? generatedID
  const width = Math.min(containerWidth, widthPercentageMax ?? containerWidth, Math.floor(containerWidth * widthPercentage))
  const side = drawerPosition === 'right' ? 1 : -1

  useEffect(() => {
    recordDrawerState(drawerID, { visible: isOpen, position: drawerPosition, width })
    return () => { recordDrawerState(drawerID, null) }
  }, [drawerID, drawerPosition, isOpen, width])
  useEffect(() => () => { progress.stopAnimation() }, [progress])

  const setVisible = useCallback((visible: boolean) => {
    if (openRef.current === visible) return
    openRef.current = visible
    Keyboard.dismiss()
    if (visible) setIsOpen(true)
    onDrawerStateChanged?.('Settling')
    Animated.timing(progress, { toValue: visible ? 1 : 0, duration: 220, useNativeDriver: true }).start(({ finished }) => {
      if (!finished) return
      if (visible) onDrawerOpen?.()
      else {
        setIsOpen(false)
        onDrawerClose?.()
      }
      onDrawerStateChanged?.('Idle')
    })
  }, [onDrawerClose, onDrawerOpen, onDrawerStateChanged, progress])

  const close = useCallback(() => {
    if (drawerLockMode !== 'locked-open') setVisible(false)
  }, [drawerLockMode, setVisible])
  useImperativeHandle(ref, () => ({
    openDrawer: () => { setVisible(true) },
    closeDrawer: () => { setVisible(false) },
    fixWidth: () => {
      container.current?.measure((_x, _y, measuredWidth) => {
        if (measuredWidth > 0) setContainerWidth(measuredWidth)
      })
    },
  }), [setVisible])

  const pan = useMemo(() => PanResponder.create({
    onMoveShouldSetPanResponder: (_event, gesture) => isOpen && drawerLockMode === 'unlocked' && gesture.dx * side > 8 && Math.abs(gesture.dx) > Math.abs(gesture.dy) * 1.5,
    onPanResponderRelease: (_event, gesture) => {
      if (gesture.dx * side > 40 || gesture.vx * side > 0.5) close()
    },
  }), [close, drawerLockMode, isOpen, side])

  return (
    <View ref={container} style={[styles.container, style]} onLayout={({ nativeEvent: { layout } }) => {
      if (layout.width > 0) setContainerWidth(layout.width)
    }}>
      <View style={styles.content} accessibilityElementsHidden={isOpen} importantForAccessibility={isOpen ? 'no-hide-descendants' : 'auto'}>
        {children}
      </View>
      <View style={styles.overlay} pointerEvents={isOpen ? 'box-none' : 'none'} accessibilityElementsHidden={!isOpen} importantForAccessibility={isOpen ? 'auto' : 'no-hide-descendants'}>
        {isOpen && <Pressable style={StyleSheet.absoluteFill} onPress={close} accessibilityRole="button" accessibilityLabel="Close menu" testID={`${drawerID}-backdrop`}>
          <Animated.View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: '#000', opacity: progress.interpolate({ inputRange: [0, 1], outputRange: [0, 0.35] }) }]} />
        </Pressable>}
        <Animated.View
          {...pan.panHandlers}
          testID={`${drawerID}-panel`}
          accessibilityViewIsModal={isOpen}
          style={[styles.panel, {
            [drawerPosition]: 0,
            width,
            backgroundColor: drawerBackgroundColor ?? theme['c-content-background'],
            transform: [{ translateX: progress.interpolate({ inputRange: [0, 1], outputRange: [side * width, 0] }) }],
          }]}
        >
          {renderNavigationView()}
        </Animated.View>
      </View>
    </View>
  )
})

const styles = StyleSheet.create({
  container: { flex: 1, overflow: 'hidden' },
  content: { flex: 1 },
  overlay: { ...StyleSheet.absoluteFillObject, zIndex: 20 },
  panel: { position: 'absolute', top: 0, bottom: 0 },
})

export default DrawerLayoutFixed
