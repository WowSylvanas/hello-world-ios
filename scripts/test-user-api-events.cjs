const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const babel = require('@babel/core')

test('native custom-source events reach multiple subscribers without changing their shared payload', () => {
  const listeners = new Set()
  const native = {
    NativeModules: { UserApiModule: { loadScript() {} } },
    NativeEventEmitter: class {
      addListener(_name, handler) {
        listeners.add(handler)
        return { remove: () => listeners.delete(handler) }
      }
    },
  }
  const filename = path.resolve('src/utils/nativeModules/userApi.ts')
  const { code } = babel.transformSync(fs.readFileSync(filename, 'utf8'), { filename })
  const module = { exports: {} }
  vm.runInNewContext('(function(require,module,exports){' + code + '\n})')(
    name => { assert.equal(name, 'react-native'); return native }, module, module.exports,
  )
  const api = module.exports
  api.loadScript({ id: 'fixture', name: 'Fixture', script: '' })
  const events = []
  const stopA = api.onScriptAction(event => events.push(event))
  const stopB = api.onScriptAction(event => events.push(event))
  const raw = { action: 'init', data: JSON.stringify({ status: true, info: { sources: {} } }) }
  const serialized = raw.data
  for (const listener of listeners) listener(raw)
  assert.equal(events.length, 2)
  assert.equal(raw.data, serialized)
  for (const event of events) {
    assert.equal(event.data.status, true)
    assert.equal(event.data.info.id, 'fixture')
  }
  stopA(); stopB()
  assert.equal(listeners.size, 0)
})
