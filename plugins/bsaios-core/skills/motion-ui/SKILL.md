---
name: motion-ui
description: "Production-ready UI motion system for React/Next.js. Use when implementing animations, transitions, or motion patterns."
origin: ECC
---

# Motion System v4.2

Production-ready UI motion system for React / Next.js.

Focused on **performance, accessibility, and usability** — not decoration.

## When to Use

Use this motion system when motion:

* Guides attention (e.g., onboarding, key actions)
* Communicates state (loading, success, error, transitions)
* Preserves spatial continuity (layout changes, navigation)

### Appropriate Scenarios

* Interactive components (buttons, modals, menus)
* State transitions (loading → loaded, open → closed)
* Navigation and layout continuity (shared elements, crossfade)

### Considerations

* **Accessibility**: Always support reduced motion
* **Device adaptation**: Adjust for low-end devices
* **Performance trade-offs**: Prefer responsiveness over visual smoothness

### Avoid Using Motion When

* It is purely decorative
* It reduces usability or clarity
* It impacts performance negatively

---

## How It Works

### Core Principle

Motion must:

* Guide attention
* Communicate state
* Preserve spatial continuity

If it does none → remove it.

---

### Installation

```bash
npm install motion
```

---

### Version

* `motion/react` - default for current Motion for React projects (package: `motion`)
* `framer-motion` - legacy import path for projects that still depend on Framer Motion

**Do not mix.** Mixing causes conflicting internal schedulers and broken `AnimatePresence` contexts — components from one package will not coordinate exit animations with components from the other.

To check which version your project uses:

```bash
cat package.json | grep -E '"motion"|"framer-motion"'
```

Always import from one source consistently:

```ts
// Correct (modern)
import { motion, AnimatePresence } from "motion/react"

// Correct (legacy)
import { motion, AnimatePresence } from "framer-motion"

// Never mix both in the same project
```

---

### Motion Tokens

```ts
// motionTokens.ts
export const motionTokens = {
  duration: {
    fast: 0.18,
    normal: 0.35,
    slow: 0.6
  },
  // Use these as the `ease` value inside a `transition` object:
  // transition={{ duration: motionTokens.duration.normal, ease: motionTokens.easing.smooth }}
  easing: {
    smooth: [0.22, 1, 0.36, 1] as [number, number, number, number],
    sharp:  [0.4,  0, 0.2, 1] as [number, number, number, number]
  },
  distance: {
    sm: 8,
    md: 16,
    lg: 24
  }
}
```

### Spring Presets

Physics-based motion (`springs.*`) feels more natural than duration-based easing for direct manipulation (drag, press, release). Centralize configs — never inline `stiffness`/`damping`.

```ts
export const springs = {
  snappy:  { type: "spring", stiffness: 300, damping: 30 }, // default UI — buttons, chips, nav
  gentle:  { type: "spring", stiffness: 120, damping: 14 }, // cards, modals, panels landing softly
  bouncy:  { type: "spring", stiffness: 400, damping: 10 }, // playful — empty states, onboarding
  instant: { type: "spring", stiffness: 600, damping: 35 }, // tooltips, popovers, dropdowns
  release: { type: "spring", stiffness: 200, damping: 20, restDelta: 0.001 } // drag release
}
```

`useSpring` vs a spring `transition`:

| | `useSpring` (motion value) | `transition: springs.*` |
|---|---|---|
| Use for | Cursor/pointer-tracked continuous values | Discrete state changes (open/closed, hover) |
| Updates | Every frame | Triggered once per state change |
| Interrupt behavior | Smooth — picks up from current velocity | Restarts from current value |

Usage example:

```tsx
import { motionTokens } from "@/lib/motionTokens"

<motion.div
  initial={{ opacity: 0, y: motionTokens.distance.md }}
  animate={{ opacity: 1, y: 0 }}
  transition={{
    duration: motionTokens.duration.normal,
    ease: motionTokens.easing.smooth
  }}
/>
```

---

### Performance Rules

**Safe**

* transform
* opacity

**Avoid**

* width / height
* top / left

Rule: responsiveness > smoothness

---

### Device Adaptation

The heuristic combines CPU core count **and** available memory for a more reliable signal. `deviceMemory` is available on Chrome/Android; the fallback covers Safari and Firefox.

```ts
const isLowEnd =
  typeof navigator !== "undefined" && (
    // Low memory (Chrome/Android only; undefined elsewhere → treat as capable)
    (navigator.deviceMemory !== undefined && navigator.deviceMemory <= 2) ||
    // Few cores AND no memory API (covers Safari/Firefox on weak hardware)
    (navigator.deviceMemory === undefined && navigator.hardwareConcurrency <= 4)
  )

const duration = isLowEnd ? 0.2 : 0.4
```

---

### Accessibility

#### JS (useReducedMotion)

```tsx
import { motion, useReducedMotion } from "motion/react"

export function FadeIn() {
  const reduce = useReducedMotion()

  return (
    <motion.div
      initial={{ opacity: 0, y: reduce ? 0 : 24 }}
      animate={{ opacity: 1, y: 0 }}
    />
  )
}
```

#### CSS

```css
@media (prefers-reduced-motion: reduce) {
  .motion-safe-transition {
    transition: opacity 0.2s;
  }

  .motion-reduce-transform {
    transform: none !important;
  }
}
```

#### Tailwind

```html
<div class="motion-safe:animate-fade motion-reduce:opacity-100"></div>
```

---

### Architecture & Patterns

#### Core Patterns

| Scenario | Pattern |
|---|---|
| Hover feedback | `whileHover` |
| Tap / press feedback | `whileTap` |
| Reveal on scroll | `whileInView` |
| Scroll-linked value | `useScroll` + `useTransform` |
| Conditional mount/unmount | `AnimatePresence` |
| Small layout shifts (single element, < ~300px change) | `layout` prop |
| Large layout shifts or full-page reflows | Avoid `layout`; use CSS transitions or page-level routing instead |
| Complex, imperative sequences | `useAnimate` |

> **Why avoid `layout` on large containers?** Framer's layout animation uses `transform` to reconcile positions, but on elements that span the full viewport or trigger deep reflow, the measurement cost causes visible jank and CLS. Prefer CSS Grid/Flexbox transitions or coordinate with `layoutId` on specific child elements only.

#### Layout & Transitions

* Shared element transitions → `layoutId` (must be unique per mounted instance)
* Enter / exit transitions → `AnimatePresence` (see `mode` guidance below)

#### AnimatePresence `mode`

Always specify `mode` explicitly — the default (`"sync"`) runs enter and exit simultaneously, which causes visual overlap in most UI patterns.

| `mode` | When to use |
|---|---|
| `"wait"` | Exit completes before enter starts. Use for **modals, toasts, page transitions**. |
| `"sync"` (default) | Enter and exit overlap. Use only when overlap is intentional (e.g., crossfade carousels). |
| `"popLayout"` | Exiting element is popped out of flow immediately; remaining items animate to fill. Use for **lists, tabs, dismissible cards**. |

```tsx
// Modal — always use "wait"
<AnimatePresence mode="wait">
  {open && <Modal key="modal" />}
</AnimatePresence>

// Dismissible list item — use "popLayout"
<AnimatePresence mode="popLayout">
  {items.map(item => <Card key={item.id} />)}
</AnimatePresence>
```

---

### Advanced Patterns (Concepts)

* Parallax (scroll-linked transforms)
* Scroll storytelling (sticky sections)
* 3D tilt (pointer-based transforms)
* Crossfade (shared `layoutId`)
* Progressive reveal (clip-path)
* Skeleton loading (looped opacity)
* Micro-interactions (hover/tap feedback)
* Spring system (physics-based motion)

---

### Modal Essentials

* Focus trap
* Escape close
* Scroll lock
* ARIA roles
* Use `AnimatePresence mode="wait"` so exit animation completes before the next modal enters

#### Full Example

```tsx
import React, { useEffect, useRef, useState } from "react"
import { motion, AnimatePresence } from "motion/react"

function useFocusTrap(ref: React.RefObject<HTMLDivElement | null>, active: boolean) {
  useEffect(() => {
    if (!active || !ref.current) return
    const el = ref.current
    const focusable = el.querySelectorAll<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    const first = focusable[0]
    const last  = focusable[focusable.length - 1]

    function handleKey(e: KeyboardEvent) {
      if (e.key !== "Tab") return
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault()
        last?.focus()
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault()
        first?.focus()
      }
    }

    el.addEventListener("keydown", handleKey)
    first?.focus()
    return () => el.removeEventListener("keydown", handleKey)
  }, [active, ref])
}

function useScrollLock(active: boolean) {
  useEffect(() => {
    if (!active) return
    const prev = document.body.style.overflow
    document.body.style.overflow = "hidden"
    return () => { document.body.style.overflow = prev }
  }, [active])
}

function Modal({ open, closeModal }: { open: boolean; closeModal: () => void }) {
  const ref = useRef<HTMLDivElement>(null)

  useFocusTrap(ref, open)
  useScrollLock(open)

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") closeModal()
    }
    if (open) window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [open, closeModal])

  return (
    // mode="wait" ensures exit animation finishes before any new modal enters
    <AnimatePresence mode="wait">
      {open && (
        <motion.div
          role="dialog"
          aria-modal="true"
          aria-labelledby="modal-title"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
          className="fixed inset-0 flex items-center justify-center bg-black/40"
        >
          <motion.div
            ref={ref}
            initial={{ scale: 0.95, opacity: 0 }}
            animate={{ scale: 1,    opacity: 1 }}
            exit={{    scale: 0.95, opacity: 0 }}
            transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
            className="bg-white p-6 rounded"
          >
            <h2 id="modal-title">Dialog Title</h2>
            <button onClick={closeModal}>Close</button>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

export function Example() {
  const [open, setOpen] = useState(false)

  return (
    <>
      <button onClick={() => setOpen(true)}>Open</button>
      <Modal open={open} closeModal={() => setOpen(false)} />
    </>
  )
}
```

---

### SSR Safety

* Match initial states between server and client renders
* Avoid implicit animation origins (always set `initial` explicitly)
* Wrap motion components in `"use client"` in Next.js App Router

When the server output truly can't equal the desired animated-in state, gate on mount instead of faking `initial`:

```tsx
"use client"
import { useState, useEffect } from "react"

const [mounted, setMounted] = useState(false)
useEffect(() => setMounted(true), [])

// initial matches server (opacity: 1) until mounted, then animates in
<motion.div
  initial={{ opacity: mounted ? 0 : 1 }}
  animate={{ opacity: 1 }}
/>
```

---

### Debugging

Check:

* Wrong import (mixing `motion/react` and `framer-motion`)
* Missing `"use client"` directive in Next.js App Router
* Missing `key` prop on `AnimatePresence` children
* Hydration mismatch (initial state differs between SSR and client)
* `layout` prop misuse on large containers causing reflow jank
* State-driven animation not triggering (check dependency arrays)

---

### QA

* No CLS
* Keyboard works
* Focus trapped in modals
* ARIA roles correct (`role="dialog"`, `aria-modal="true"`)
* Reduced motion respected (`useReducedMotion` + CSS media query)
* No hydration warnings in Next.js
* Animations stop cleanly on unmount (no memory leaks)
* `AnimatePresence mode` set explicitly on all usage sites

---

### Anti-Patterns

* Animating layout properties (`width`, `height`, `top`, `left`)
* Infinite animations without purpose (always ask: what state does this communicate?)
* Over-staggering lists (keep `staggerChildren` ≤ 0.1s; beyond that it feels slow)
* Ignoring reduced motion preferences
* Using `layout` on large or full-viewport containers
* Omitting `mode` on `AnimatePresence` (default `"sync"` causes visual overlap)
* Using motion purely for decoration
* Defining `initial` + `animate` without `exit` — an animation without an exit is incomplete; `AnimatePresence` needs a `key` on the direct child or the exit silently never fires
* `animate={{ repeat: Infinity }}` with no pause — background tabs must not burn CPU/GPU; stop on `document.visibilityState === "hidden"` and restart on visibility change
* Recreating a motion value on render (`new MotionValue(0)` instead of `useMotionValue(0)` in the component body)
* Adding a `window`/`document` listener in a hook without a matching cleanup in the `useEffect` return

---

### Philosophy

Motion is interaction design.

---

### Final Rule

> If motion does not improve UX → remove it.

---

## Examples

### Button Interaction

```tsx
import { motion } from "motion/react"

export function Button() {
  return (
    <motion.button
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.97 }}
      transition={{ duration: 0.15, ease: [0.4, 0, 0.2, 1] }}
    >
      Click me
    </motion.button>
  )
}
```

---

### Reduced Motion Example

```tsx
import { motion, useReducedMotion } from "motion/react"

export function FadeIn() {
  const reduce = useReducedMotion()

  return (
    <motion.div
      initial={{ opacity: 0, y: reduce ? 0 : 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: reduce ? 0.1 : 0.35, ease: [0.22, 1, 0.36, 1] }}
    />
  )
}
```

---

### Stagger List

```tsx
import { motion } from "motion/react"

const container = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.08 } // keep ≤ 0.1s to avoid sluggishness
  }
}

const item = {
  hidden:  { opacity: 0, y: 10 },
  visible: { opacity: 1, y: 0,  transition: { duration: 0.3, ease: [0.22, 1, 0.36, 1] } }
}

export function List() {
  return (
    <motion.ul variants={container} initial="hidden" animate="visible">
      {[1, 2, 3].map(i => (
        <motion.li key={i} variants={item}>Item {i}</motion.li>
      ))}
    </motion.ul>
  )
}
```

---

### Modal with AnimatePresence

```tsx
import { motion, AnimatePresence } from "motion/react"

export function Modal({ open }: { open: boolean }) {
  return (
    <AnimatePresence mode="wait">
      {open && (
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1    }}
          exit={{    opacity: 0, scale: 0.95 }}
          transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
        />
      )}
    </AnimatePresence>
  )
}
```

---

### Scroll Parallax

```tsx
import { useScroll, useTransform, motion } from "motion/react"

export function Parallax() {
  const { scrollYProgress } = useScroll()
  const y = useTransform(scrollYProgress, [0, 1], [0, -80])

  return <motion.div style={{ y }} />
}
```

---

### Skeleton Loading

```tsx
"use client"
import { useEffect } from "react"
import { motion, useAnimation } from "motion/react"

export function Skeleton() {
  const controls = useAnimation()

  useEffect(() => {
    const pulse = () =>
      controls.start({
        opacity: [0.5, 1, 0.5],
        transition: { duration: 1.5, repeat: Infinity, ease: "easeInOut" }
      })

    // Pause on hidden tabs — infinite animations must not burn CPU/GPU in the background
    const onVisibility = () => {
      if (document.visibilityState === "hidden") controls.stop()
      else void pulse()
    }

    void pulse()
    document.addEventListener("visibilitychange", onVisibility)
    return () => {
      controls.stop()
      document.removeEventListener("visibilitychange", onVisibility)
    }
  }, [controls])

  return <motion.div className="bg-gray-200 h-6 w-full rounded" animate={controls} />
}
```

---

### Drag to Dismiss

```tsx
"use client"
import { motion, useMotionValue, useTransform } from "motion/react"

export function BottomSheet({ onClose }: { onClose: () => void }) {
  const y = useMotionValue(0)
  const opacity = useTransform(y, [0, 200], [1, 0])

  return (
    <motion.div
      drag="y"
      dragConstraints={{ top: 0 }}
      style={{ y, opacity }}
      onDragEnd={(_, info) => {
        // Never infer intent from velocity alone — combine offset + velocity
        if (info.offset.y > 120 || info.velocity.y > 500) onClose()
      }}
    />
  )
}
```

Test `drag` on real touch devices, not just mouse — feel and threshold differ from desktop.

---

### Reorderable List

```tsx
"use client"
import { Reorder } from "motion/react"

export function SortableList({ items, setItems }: {
  items: { id: string; label: string }[]
  setItems: (items: { id: string; label: string }[]) => void
}) {
  return (
    <Reorder.Group axis="y" values={items} onReorder={setItems}>
      {items.map((item) => (
        <Reorder.Item key={item.id} value={item}>{item.label}</Reorder.Item>
      ))}
    </Reorder.Group>
  )
}
```

---

### Number Counter (KPI tiles)

```tsx
"use client"
import { useRef, useEffect } from "react"
import { animate } from "motion"

export function Counter({ to }: { to: number }) {
  const nodeRef = useRef<HTMLSpanElement>(null)

  useEffect(() => {
    const controls = animate(0, to, {
      duration: 1,
      ease: [0.22, 1, 0.36, 1],
      onUpdate: (v) => {
        if (nodeRef.current) nodeRef.current.textContent = Math.round(v).toString()
      }
    })
    return controls.stop
  }, [to])

  return <span ref={nodeRef} />
}
```

---

### useAnimate (imperative sequences)

Returns `[scope, animate]`. The `scope` ref must be attached to a **mounted** DOM element — calling `animate()` before mount fails silently. Calls are interrupt-safe: calling `animate()` mid-flight cancels the previous run.

```tsx
const [scope, animate] = useAnimate()

async function play() {
  await animate(".step-1", { opacity: 1 }, { duration: 0.3 })
  await animate(".step-2", { x: 0 },       { duration: 0.4 })
        animate(".step-3", { scale: 1 },    { duration: 0.25 }) // fire and forget
}

return <div ref={scope}>...</div>
```

---

### Shared Layout (Crossfade)

```tsx
import { motion } from "motion/react"

// layoutId must be unique per mounted instance.
// If multiple instances can exist simultaneously, append a unique id:
// layoutId={`shared-${item.id}`}
export function Shared() {
  return <motion.div layoutId="shared" />
}
```
