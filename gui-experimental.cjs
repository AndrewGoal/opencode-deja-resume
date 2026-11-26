// deja-resume: opens a session tab in the OpenCode desktop app on request.
//
// `deja resume <id> --exec` (through the `opencode` shim) writes
// ~/.local/share/opencode/deja-resume.json and starts the app. The main
// process watches that file and asks the window plugin to open the tab.
const { Plugin } = require("@opencode/plugin/gui")

module.exports = Plugin.define({
  setup(ctx) {
    // Called from main through webContents.executeJavaScript.
    globalThis.__opencodeDejaResume = (sessionID) => {
      if (typeof sessionID !== "string" || !sessionID.startsWith("ses_")) return false

      const server = ctx.servers
        .list()
        .map((id) => ctx.servers.get(id))
        .find((entry) => entry && entry.builtin)
      if (!server) return false

      ctx.tabs.open({ server: server.id, id: sessionID }, { focus: true })

      // Focus the tab again once the strip lists it: the app's own restore
      // can put the previously active tab back on screen right after open.
      const focus = () => {
        const tab = ctx.tabs
          .list()
          .find((entry) => entry.session?.id === sessionID && entry.session?.server.id === server.id)
        if (tab) ctx.tabs.focus(tab.key)
      }
      focus()
      setTimeout(focus, 100)
      setTimeout(focus, 400)
      return true
    }
  },

  main(ctx) {
    const fs = require("node:fs")
    const os = require("node:os")
    const path = require("node:path")

    const data = process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local", "share")
    const request = path.join(data, "opencode", "deja-resume.json")
    // A request the app could not handle in time must not fire much later.
    const maxAge = 2 * 60 * 1000
    let pending

    const read = () => {
      try {
        const data = JSON.parse(fs.readFileSync(request, "utf8"))
        if (typeof data.session !== "string" || !data.session.startsWith("ses_")) return undefined
        if (typeof data.time === "number" && Date.now() - data.time > maxAge) return undefined
        return data.session
      } catch {
        return undefined
      }
    }

    const clear = () => {
      try {
        fs.rmSync(request, { force: true })
      } catch {}
    }

    const open = () => {
      const session = pending
      if (!session) return
      const windows = ctx.windows.list()
      const target = ctx.windows.focused() ?? windows[windows.length - 1]
      if (!target || target.isDestroyed()) return

      Promise.resolve(
        target.webContents.executeJavaScript(
          `window.__opencodeDejaResume && window.__opencodeDejaResume(${JSON.stringify(session)})`,
          true,
        ),
      )
        .then((opened) => {
          if (opened !== true) return
          if (pending === session) pending = undefined
          if (read() === session) clear()
          if (target.isMinimized()) target.restore()
          target.show()
          target.focus()
        })
        .catch(() => {})
    }

    const poll = () => {
      const session = read()
      if (!session) {
        // Expired or removed: drop the file so it cannot fire later.
        pending = undefined
        clear()
        return
      }
      pending = session
      open()
    }

    const timer = setInterval(poll, 500)
    poll()
    ctx.onCleanup(() => clearInterval(timer))
  },
})
