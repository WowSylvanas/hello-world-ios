import { NativeModules } from 'react-native'

// Only the simulator smoke runner records committed drawer visibility.
export interface DrawerState { visible: boolean, position: 'left' | 'right', width: number }
export const drawerStates = new Map<string, DrawerState>()
export const recordDrawerState = (id: string, state: DrawerState | null) => {
  if (!NativeModules.UtilsModule.smokeTestRequested) return
  if (state === null) drawerStates.delete(id)
  else drawerStates.set(id, state)
}
