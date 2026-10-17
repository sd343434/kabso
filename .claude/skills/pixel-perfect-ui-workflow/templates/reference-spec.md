# Reference specification — <screen> (<locale>)

> Produced by `pixel-perfect-reference-analyzer`. Every value is tagged **M** (measured from pixels with
> `measure.py`, command recorded) or **E** (estimate, with the reason). Untagged numbers are not allowed.

## 1. Reference record (Gate A)

| Field | Value |
| ----- | ----- |
| File (outside the public repo if it contains third-party content) | |
| sha256 | |
| Pixel size | M: |
| Logical viewport | M/E: (state how known) |
| Device pixel ratio | M/E: |
| Device / OS (if known) | |
| Locale and direction | |
| Target Kabso screen + route | |
| App state shown (logged in? tab? data?) | |
| Authorization | who supplied it, date, allowed use (pattern reference / exact implementation) |
| Status bar / safe-area insets | M: top __, bottom __ (px and lp) |

## 2. Region map

| ID | Region | x | y | w | h | Units | Tag | Command |
| -- | ------ | - | - | - | - | ----- | --- | ------- |
| R1 | status bar | | | | | lp | M | `measure.py vline ...` |

## 3. Component hierarchy

```
Screen
└─ R2 Header
   ├─ Title (text)
   └─ Actions (icon ×2)
```

## 4. Component specs

For each component: position, size, padding, margin, alignment, radius, border, background (hex + alpha),
foreground, typography (family/size/weight/line height — **E** unless verified), icon size, image crop
(aspect, fit, focal point), states (selected/pressed/disabled), and RTL behaviour.

| Component | Property | Value | Tag | Evidence |
| --------- | -------- | ----- | --- | -------- |

## 5. Colour table

| Token candidate | Hex | Alpha | Where sampled (px) | Tag |
| --------------- | --- | ----- | ------------------ | --- |

## 6. Assets

| Asset | In project? (path) | Exact match? | Licence / authorization | Action |
| ----- | ------------------ | ------------ | ----------------------- | ------ |

## 7. Uncertainty and blockers

- What could not be measured and why (compression, scaling, overlapping content, unknown font).
- Elements that must NOT be copied (third-party logos, brand marks, mascots, proprietary icons, user photos).
