/**
 * Measures active reading time. Time between two pieces of activity (scroll,
 * key press, pointer) counts, but at most `idleCapMs` per gap, so a reader who
 * walks away does not keep accumulating time. Paused while the page is hidden.
 */
export class ReadingTimer {
  private creditedMs = 0
  private lastActivity: number
  private paused = false

  constructor(
    private readonly now: () => number = () => Date.now(),
    private readonly idleCapMs = 2 * 60 * 1000,
  ) {
    this.lastActivity = now()
  }

  /** Records activity, crediting the time since the previous activity. */
  activity() {
    const t = this.now()
    if (!this.paused) this.creditedMs += Math.min(Math.max(0, t - this.lastActivity), this.idleCapMs)
    this.lastActivity = t
  }

  pause() {
    if (this.paused) return
    this.activity()
    this.paused = true
  }

  resume() {
    if (!this.paused) return
    this.paused = false
    this.lastActivity = this.now()
  }

  /** Whole seconds read since the last take(), capped at `maxSeconds`. */
  take(maxSeconds = 1800): number {
    this.activity()
    const whole = Math.floor(this.creditedMs / 1000)
    const seconds = Math.min(maxSeconds, whole)
    // Keep the sub-second remainder unless the report was capped.
    this.creditedMs = whole > maxSeconds ? 0 : this.creditedMs - seconds * 1000
    return seconds
  }
}
