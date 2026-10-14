import { describe, expect, it } from 'vitest'
import { ReadingTimer } from '~/utils/readingTimer'

function clock(start = 0) {
  let t = start
  return { now: () => t, advance: (ms: number) => { t += ms } }
}

describe('ReadingTimer', () => {
  it('counts time between activity', () => {
    const c = clock()
    const timer = new ReadingTimer(c.now)
    c.advance(30_000)
    timer.activity()
    c.advance(15_000)
    expect(timer.take()).toBe(45)
    expect(timer.take()).toBe(0)
  })

  it('caps each idle gap', () => {
    const c = clock()
    const timer = new ReadingTimer(c.now, 60_000)
    c.advance(10 * 60_000)
    expect(timer.take()).toBe(60)
  })

  it('does not count time while paused', () => {
    const c = clock()
    const timer = new ReadingTimer(c.now)
    c.advance(10_000)
    timer.pause()
    c.advance(100_000)
    timer.activity()
    timer.resume()
    c.advance(5_000)
    expect(timer.take()).toBe(15)
  })

  it('caps one report and keeps sub-second remainders', () => {
    const c = clock()
    const timer = new ReadingTimer(c.now, 10 * 60_000)
    for (let i = 0; i < 5; i++) {
      c.advance(10 * 60_000)
      timer.activity()
    }
    expect(timer.take(1800)).toBe(1800)
    expect(timer.take()).toBe(0)
    c.advance(1_500)
    expect(timer.take()).toBe(1)
    c.advance(600)
    expect(timer.take()).toBe(1)
  })
})
