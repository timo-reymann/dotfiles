/**
 * OpenCode statusline plugin.
 *
 * Port of the Claude Code statusline (~/.bin/claude-statusline) to the
 * OpenCode TUI. Replaces the built-in prompt footer row (which carries the
 * tokens/context/cost chip) with:
 *
 *   ⎇branch*  💰$cost  📅month%·☀️day%  🪟ctx%  ⏱duration  ⏳5h%·7d%·mo%  🔧mcp
 *
 * On the home screen the same row is appended to home.footer.status.
 *
 * - 💰 sums the session family (root + subagents), matching the built-in chip.
 * - 🪟 shows the context window percentage of the selected model's limit.
 * - ⏱ sums assistant message work time (created → completed) for the session.
 * - 📅☀️ budget measures OpenCode spend (all providers) from
 *   /api/experimental/session/stats, polled every 120 s. Monthly limit from
 *   OPENCODE_MONTHLY_LIMIT_USD (fallback CLAUDE_MONTHLY_LIMIT_USD); daily
 *   limit = monthly / workdays (Mon–Fri), same rule as ~/.bin/claude-budget.
 *   The segment hides without a limit.
 * - ⏳ OpenCode Go quota (5h rolling, 7d weekly, monthly), scraped from
 *   opencode.ai every 5 min. Needs OPENCODE_GO_WORKSPACE_ID and
 *   OPENCODE_GO_AUTH_COOKIE; hides until both are set. Parsing adapted from
 *   Sakihana/opencode-quota-statusline (MIT).
 * - Threshold colors follow ~/.bin/claude-statusline: green <50, yellow <80,
 *   red >=80.
 *
 * Solid note: every segment reads its signal inside the JSX expression so the
 * row re-renders when async data arrives. Never hoist signal reads into
 * component body variables.
 */
/** @jsxImportSource @opentui/solid */
import { createEffect, createMemo, createRoot, createSignal } from "solid-js"
import { execFile } from "node:child_process"
import https from "node:https"
import { Plugin } from "@opencode/plugin/tui"

// ---------------- Go quota scraping (adapted from Sakihana, MIT) ------------

const readGoAuth = (env = process.env) => {
  const workspaceId = env.OPENCODE_GO_WORKSPACE_ID
  const cookie = env.OPENCODE_GO_AUTH_COOKIE
  if (workspaceId && cookie) return { workspaceId, cookie }
  return undefined
}

const httpsGet = (url: string, cookie: string) =>
  new Promise<string>((resolve, reject) => {
    const req = https.get(url, { headers: { Cookie: cookie } }, (res) => {
      const chunks: Buffer[] = []
      res.on("data", (c) => chunks.push(c as Buffer))
      res.on("end", () => {
        if (res.statusCode && res.statusCode >= 300) {
          reject(new Error(`OpenCode Go request failed (${res.statusCode})`))
          return
        }
        resolve(Buffer.concat(chunks).toString("utf8"))
      })
    })
    req.on("error", reject)
    req.setTimeout(15000, () => req.destroy(new Error("Request timeout")))
  })

const parseUsageObject = (raw: string) => {
  const body = raw.replace(/^\$R\[\d+\]=/, "")
  const resetInSec = body.match(/resetInSec:(\d+)/)?.[1]
  const usagePercent = body.match(/usagePercent:(\d+(?:\.\d+)?)/)?.[1]
  if (usagePercent === undefined) return undefined
  return {
    usagePercent: Number(usagePercent),
    resetInSec: resetInSec ? Number(resetInSec) : undefined,
  }
}

const findUsageDeep = (input: any): any => {
  if (!input || typeof input !== "object") return null
  if ("rollingUsage" in input || "weeklyUsage" in input || "monthlyUsage" in input) return input
  for (const v of Object.values(input)) {
    const hit = findUsageDeep(v)
    if (hit) return hit
  }
  return null
}

const extractUsage = (html: string) => {
  const scripts = html.match(/<script[^>]*>([\s\S]*?)<\/script>/gi) ?? []
  for (const tag of scripts) {
    if (!tag.includes("rollingUsage")) continue
    const usage: Record<string, { usagePercent: number; resetInSec?: number } | null> = {}
    for (const key of ["rollingUsage", "weeklyUsage", "monthlyUsage"]) {
      const m = tag.match(new RegExp(`${key}:(\\$R\\[\\d+\\]=\\{[^}]*\\}|null|undefined)`))
      usage[key] = !m || m[1] === "null" || m[1] === "undefined" ? null : parseUsageObject(m[1])
    }
    if (usage.rollingUsage || usage.weeklyUsage || usage.monthlyUsage) return usage
    const obj = tag.match(/\{[\s\S]*rollingUsage[\s\S]*\}/)
    if (obj) {
      try {
        const hit = findUsageDeep(JSON.parse(obj[0]))
        if (hit) return hit
      } catch {}
    }
  }
  return null
}

const fetchGoQuota = async () => {
  const auth = readGoAuth()
  if (!auth) return []
  try {
    const html = await httpsGet(
      `https://opencode.ai/workspace/${auth.workspaceId}/go`,
      `auth=${auth.cookie}`,
    )
    const usage = extractUsage(html)
    if (!usage) return []
    const out: { label: string; pct: number }[] = []
    const add = (label: string, u: { usagePercent?: number } | null) => {
      if (u && typeof u.usagePercent === "number") out.push({ label, pct: u.usagePercent })
    }
    add("5h", usage.rollingUsage)
    add("7d", usage.weeklyUsage)
    add("mo", usage.monthlyUsage)
    return out
  } catch {
    return []
  }
}

// ---------------- plugin ----------------

export default Plugin.define({
  id: "timo.statusline",
  setup(context: any) {
    // ---------------- signals ----------------
    const [budget, setBudget] = createSignal<{ m: number; d: number } | null>(null)
    const [gitInfo, setGitInfo] = createSignal<{ branch: string; dirty: boolean } | null>(null)
    const [mcpCount, setMcpCount] = createSignal(0)
    const [sess, setSess] = createSignal<{ cost: number; ctx: number; used: number; dur: number } | null>(null)
    const [goQuota, setGoQuota] = createSignal<{ label: string; pct: number }[]>([])

    // ---------------- colors ----------------
    const pick = (...vals: any[]): any => {
      for (const v of vals) {
        if (typeof v === "string") return v
        if (v && typeof v === "object") {
          if (typeof (v as any).r === "number") return v
          if (typeof (v as any).base === "string") return (v as any).base
          if (typeof (v as any).primary === "string") return (v as any).primary
        }
      }
      return undefined
    }
    const th: any = (context as any).theme ?? {}
    const C = {
      ok: pick(th.success, th.status?.success) ?? "#3fb950",
      warn: pick(th.warning, th.status?.warning) ?? "#d29922",
      bad: pick(th.error, th.status?.error) ?? "#f85149",
      dim: pick(th.text?.muted, th.textMuted) ?? "#8b949e",
      base: pick(th.text?.base, th.text) ?? "#e6edf3",
      cyan: pick(th.cyan, th.status?.cyan) ?? "#00bcd4",
      blue: pick(th.info, th.status?.info) ?? "#58a6ff",
      money: "#ff8700",
    }
    const pctColor = (p: number) => (p >= 80 ? C.bad : p >= 50 ? C.warn : C.ok)

    // ---------------- helpers ----------------
    const dir: string = context.location?.directory ?? process.cwd()
    const location: any = context.location ?? context.data?.location?.default?.()

    const run = (cmd: string, args: string[], timeout = 30000) =>
      new Promise<string>((resolve, reject) => {
        execFile(cmd, args, { timeout, maxBuffer: 10 * 1024 * 1024 }, (err, stdout) =>
          err ? reject(err) : resolve(String(stdout)),
        )
      })

    const limitEnv = (): number => {
      for (const k of ["OPENCODE_MONTHLY_LIMIT_USD", "CLAUDE_MONTHLY_LIMIT_USD"]) {
        const v = Number(process.env[k])
        if (Number.isFinite(v) && v > 0) return v
      }
      return 0
    }

    const workdays = (y: number, m: number): number => {
      const last = new Date(y, m + 1, 0).getDate()
      let n = 0
      for (let d = 1; d <= last; d++) {
        const wd = new Date(y, m, d).getDay()
        if (wd >= 1 && wd <= 5) n++
      }
      return n || 1
    }

    // ---------------- budget (OpenCode spend) ----------------
    let budgetBusy = false
    const statsCost = async (fromMs: number): Promise<number> => {
      const out = await run("opencode", ["api", "get", `/api/experimental/session/stats?from=${fromMs}`])
      return Number(JSON.parse(out)?.data?.cost ?? 0)
    }
    const refreshBudget = async () => {
      const limit = limitEnv()
      if (!limit) {
        setBudget(null)
        return
      }
      if (budgetBusy) return
      budgetBusy = true
      try {
        const now = new Date()
        const mCost = await statsCost(new Date(now.getFullYear(), now.getMonth(), 1).getTime())
        const dCost = await statsCost(
          new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime(),
        )
        const dayLimit = limit / workdays(now.getFullYear(), now.getMonth())
        setBudget({ m: (mCost / limit) * 100, d: (dCost / dayLimit) * 100 })
      } catch {
        // keep the last value; the next tick retries
      }
      budgetBusy = false
    }

    // ---------------- git ----------------
    const refreshGit = async () => {
      try {
        const branch = (await run("git", ["-C", dir, "branch", "--show-current"], 5000)).trim()
        if (!branch) {
          setGitInfo(null)
          return
        }
        const st = await run("git", ["-C", dir, "status", "--porcelain", "--untracked-files=no"], 5000)
        setGitInfo({ branch, dirty: st.trim().length > 0 })
      } catch {
        setGitInfo(null)
      }
    }

    // ---------------- session: cost (family) + context ----------------
    const limitCache = new Map<string, number>()
    const modelLimit = async (modelID: string, providerID: string): Promise<number> => {
      const cacheKey = `${providerID}/${modelID}`
      const hit = limitCache.get(cacheKey)
      if (hit) return hit
      try {
        await context.data.location.model.sync(location)
        const items: any[] = context.data.location.model.list(location) ?? []
        const m =
          items.find((x) => x.modelID === modelID && x.providerID === providerID) ??
          items.find((x) => x.id === modelID && x.providerID === providerID)
        const limit = Number(m?.limit?.context ?? 0)
        if (limit) limitCache.set(cacheKey, limit)
        return limit
      } catch {
        return 0
      }
    }

    const currentModel = (): any => {
      try {
        return context.ui?.model?.current() ?? null
      } catch {
        return null
      }
    }

    // Sum the session family (root + subagents) so the cost matches the
    // built-in chip, which includes subagent spend.
    const familyCost = async (sessionID: string): Promise<number> => {
      const ids = new Set<string>([sessionID])
      try {
        const root = context.data.session.root?.(sessionID)
        if (root) ids.add(String(root))
        for (const id of context.data.session.family?.(root ?? sessionID) ?? []) ids.add(String(id))
      } catch {}
      let total = 0
      for (const id of ids) {
        try {
          await context.data.session.sync(id)
          total += Number(context.data.session.cost(id) ?? 0)
        } catch {}
      }
      return total
    }

    const refreshSession = async (sessionID?: string) => {
      if (!sessionID) {
        setSess(null)
        return
      }
      try {
        await context.data.session.sync(sessionID)
        const cost = await familyCost(sessionID)
        await context.data.session.message.sync(sessionID)
        const msgs: any[] = context.data.session.message.list(sessionID) ?? []
        let tokens: any
        let dur = 0
        for (const item of msgs) {
          const m: any = item?.info ?? item
          if (m?.type !== "assistant" && m?.role !== "assistant") continue
          const t: any = m?.time
          if (t?.created && t?.completed) dur += Math.max(0, Number(t.completed) - Number(t.created))
          if (m?.tokens != null) tokens = m.tokens
        }
        if (!tokens) {
          const s: any = context.data.session.get(sessionID)
          tokens = s?.tokens
        }
        let used = 0
        let ctx = 0
        if (tokens) {
          used =
            Number(tokens.input ?? 0) +
            Number(tokens.output ?? 0) +
            Number(tokens.reasoning ?? 0) +
            Number(tokens.cache?.read ?? 0) +
            Number(tokens.cache?.write ?? 0)
          const cur = currentModel()
          const mid: string = cur?.modelID ?? cur?.id ?? ""
          const pid: string = cur?.providerID ?? ""
          const limit = mid ? await modelLimit(mid, pid) : 0
          if (limit > 0) ctx = (used / limit) * 100
        }
        setSess({ cost, ctx, used, dur })
      } catch {
        setSess(null)
      }
    }

    // ---------------- reactive wiring ----------------
    const dispose = createRoot((d) => {
      const sessionID = createMemo<string | undefined>(() => {
        try {
          const r: any = context.ui?.router?.current?.()
          if (r && (r.type === "session" || r.name === "session")) {
            return String(r.sessionID ?? r.data?.sessionID ?? "") || undefined
          }
        } catch {
          // older build without the router API: no session segments
        }
        return undefined
      })

      createEffect(() => {
        void refreshSession(sessionID())
      })

      return { sessionID, d }
    })

    const sessionID = () => dispose.sessionID()

    // Poll fallback so cost/ctx stay fresh even without events.
    const sessTimer = setInterval(() => void refreshSession(sessionID()), 10000)

    // ---------------- mcp ----------------
    void (async () => {
      try {
        await context.data.location.mcp.server.sync(location)
        setMcpCount(context.data.location.mcp.server.list(location)?.length ?? 0)
      } catch {
        setMcpCount(0)
      }
    })()

    // ---------------- server events ----------------
    let debounce: ReturnType<typeof setTimeout> | undefined
    const stopListen = context.data.listen(({ details }: any) => {
      const t = details?.type ?? details
      if (typeof t === "string" && /message|session|step|part/i.test(t)) {
        clearTimeout(debounce)
        debounce = setTimeout(() => void refreshSession(sessionID()), 500)
      }
    })

    // ---------------- Go quota ----------------
    let goBusy = false
    const refreshGoQuota = async () => {
      if (!readGoAuth()) {
        setGoQuota([])
        return
      }
      if (goBusy) return
      goBusy = true
      try {
        setGoQuota(await fetchGoQuota())
      } catch {
        // keep the last value; the next tick retries
      }
      goBusy = false
    }

    // ---------------- timers ----------------
    const budgetTimer = setInterval(() => void refreshBudget(), 120000)
    const gitTimer = setInterval(() => void refreshGit(), 30000)
    const goTimer = setInterval(() => void refreshGoQuota(), 300000)
    void refreshBudget()
    void refreshGit()
    void refreshGoQuota()

    // ---------------- render ----------------
    // Every segment reads its signal inside JSX so updates propagate.
    // Order and colors match the Claude statusline:
    // ⎇ branch (cyan) · 💰 cost (orange) · 📅☀️ budget (tiered) ·
    // 🪟 context (tiered) · ⏱ duration (white) · ⏳ Go quota (tiered) · 🔧 MCP (blue)
    const Row = () => (
      <box flexDirection="row">
        {(() => {
          const g = gitInfo()
          return g ? <text fg={C.cyan}>{`⎇ ${g.branch}${g.dirty ? "*" : ""}`}</text> : null
        })()}
        {(() => {
          const s = sess()
          return s && s.cost > 0 ? <text fg={C.money}>{`  💰$${s.cost.toFixed(4)}`}</text> : null
        })()}
        {(() => {
          const b = budget()
          return b ? <text fg={pctColor(b.m)}>{`  📅${Math.round(b.m)}%`}</text> : null
        })()}
        {budget() ? <text fg={C.dim}>·</text> : null}
        {(() => {
          const b = budget()
          return b ? <text fg={pctColor(b.d)}>{`☀️${Math.round(b.d)}%`}</text> : null
        })()}
        {(() => {
          const s = sess()
          return s && s.ctx > 0 ? <text fg={pctColor(s.ctx)}>{`  🪟${Math.round(s.ctx)}%`}</text> : null
        })()}
        {(() => {
          const s = sess()
          if (!s || s.dur <= 0) return null
          const m = Math.floor(s.dur / 60000)
          const sec = Math.floor((s.dur % 60000) / 1000)
          return <text fg={C.base}>{`  ⏱ ${m}m${String(sec).padStart(2, "0")}s`}</text>
        })()}
        {(() => {
          const q = goQuota()
          if (q.length === 0) return null
          return (
            <box flexDirection="row">
              <text fg={C.dim}>{`  ⏳`}</text>
              {q.map((w, i) => (
                <text fg={pctColor(w.pct)}>{`${i > 0 ? "·" : ""}${w.label}${Math.round(w.pct)}%`}</text>
              ))}
            </box>
          )
        })()}
        {mcpCount() > 0 ? <text fg={C.blue}>{`  🔧${mcpCount()}`}</text> : null}
      </box>
    )

    const un1 = context.ui.slot({ replace: "prompt.footer", render: () => <Row /> })
    const un2 = context.ui.slot({ append: "home.footer.status", render: () => <Row /> })

    return () => {
      clearInterval(sessTimer)
      clearInterval(budgetTimer)
      clearInterval(gitTimer)
      clearInterval(goTimer)
      clearTimeout(debounce)
      try {
        stopListen?.()
      } catch {}
      if (typeof un1 === "function") un1()
      if (typeof un2 === "function") un2()
      dispose.d()
    }
  },
})
