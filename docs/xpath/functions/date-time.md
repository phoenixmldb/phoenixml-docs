---
title: Date and Time Functions
description: XPath date/time construction, extraction, formatting, and timezone handling
sort: 3
---

# Date and Time Functions

XPath has first-class date and time types — unlike JSON where dates are just strings. This means you can compare dates, extract components, add durations, and format for display without parsing strings yourself.

If you've struggled with `DateTime.Parse()` and format strings in C#, XPath's approach will feel more structured.

## Contents

- [Current Date and Time](#current-date-and-time)
- [Component Extraction](#component-extraction)
- [Timezone Operations](#timezone-operations)
- [Construction](#construction)
- [Formatting](#formatting)

---

## Current Date and Time

### current-date()

Returns today's date.

**Signature:** `current-date() as xs:date`

```xpath
current-date()   => 2026-03-19
```

**C# equivalent:** `DateOnly.FromDateTime(DateTime.Now)` or `DateTime.Today`

**Note:** The returned date includes timezone information from the evaluation context. Within a single XPath evaluation, `current-date()` always returns the same value — it's captured once at the start, not each time the function is called.

---

### current-time()

Returns the current time.

**Signature:** `current-time() as xs:time`

```xpath
current-time()   => 14:30:00-05:00
```

**C# equivalent:** `TimeOnly.FromDateTime(DateTime.Now)`

---

### current-dateTime()

Returns the current date and time.

**Signature:** `current-dateTime() as xs:dateTime`

```xpath
current-dateTime()   => 2026-03-19T14:30:00-05:00
```

**C# equivalent:** `DateTimeOffset.Now`

**Important:** Like `current-date()`, this value is stable within a single evaluation. If your XSLT processes 1000 documents, they all see the same timestamp.

---

## Component Extraction

These functions extract parts from date, time, and dateTime values. Each has variants for date, time, and dateTime inputs.

### year-from-date() / year-from-dateTime()

**Signature:** `year-from-date($value as xs:date?) as xs:integer?`

```xpath
year-from-date(xs:date("2026-03-19"))         => 2026
year-from-dateTime(current-dateTime())        => 2026
```

**C# equivalent:** `date.Year`

---

### month-from-date() / month-from-dateTime()

**Signature:** `month-from-date($value as xs:date?) as xs:integer?`

```xpath
month-from-date(xs:date("2026-03-19"))        => 3
```

**C# equivalent:** `date.Month`

---

### day-from-date() / day-from-dateTime()

**Signature:** `day-from-date($value as xs:date?) as xs:integer?`

```xpath
day-from-date(xs:date("2026-03-19"))          => 19
```

**C# equivalent:** `date.Day`

---

### hours-from-time() / hours-from-dateTime()

**Signature:** `hours-from-time($value as xs:time?) as xs:integer?`

```xpath
hours-from-time(xs:time("14:30:00"))          => 14
```

**C# equivalent:** `time.Hour`

---

### minutes-from-time() / minutes-from-dateTime()

```xpath
minutes-from-time(xs:time("14:30:00"))        => 30
```

---

### seconds-from-time() / seconds-from-dateTime()

```xpath
seconds-from-time(xs:time("14:30:45.5"))      => 45.5
```

**Note:** Returns a `xs:decimal`, not an integer — it includes fractional seconds.

---

### Duration Component Extraction

For `xs:duration`, `xs:yearMonthDuration`, and `xs:dayTimeDuration`:

```xpath
years-from-duration(xs:yearMonthDuration("P2Y3M"))   => 2
months-from-duration(xs:yearMonthDuration("P2Y3M"))  => 3
days-from-duration(xs:dayTimeDuration("P5DT3H"))     => 5
hours-from-duration(xs:dayTimeDuration("P5DT3H"))    => 3
```

**C# equivalent:** `timeSpan.Days`, `timeSpan.Hours`, etc.

---

## Timezone Operations

### timezone-from-date() / timezone-from-dateTime() / timezone-from-time()

Extracts the timezone as a `dayTimeDuration`.

```xpath
timezone-from-date(xs:date("2026-03-19-05:00"))   => -PT5H
timezone-from-dateTime(current-dateTime())          => timezone of eval context
```

**C# equivalent:** `dateTimeOffset.Offset`

---

### adjust-dateTime-to-timezone()

Adjusts a dateTime to a different timezone.

**Signature:** `adjust-dateTime-to-timezone($value as xs:dateTime?, $timezone as xs:dayTimeDuration?) as xs:dateTime?`

```xpath
(: Convert from UTC to US Eastern :)
adjust-dateTime-to-timezone(
  xs:dateTime("2026-03-19T14:00:00Z"),
  xs:dayTimeDuration("-PT5H")
)
=> 2026-03-19T09:00:00-05:00

(: Strip timezone — make it "local" :)
adjust-dateTime-to-timezone(
  xs:dateTime("2026-03-19T14:00:00Z"),
  ()
)
=> 2026-03-19T14:00:00
```

**C# equivalent:** `dateTimeOffset.ToOffset(new TimeSpan(-5, 0, 0))`

Variants: `adjust-date-to-timezone()`, `adjust-time-to-timezone()`

---

## Construction

### dateTime()

Constructs a `xs:dateTime` from separate date and time values.

**Signature:** `dateTime($date as xs:date?, $time as xs:time?) as xs:dateTime?`

```xpath
dateTime(xs:date("2026-03-19"), xs:time("14:30:00"))
=> 2026-03-19T14:30:00
```

**C# equivalent:** `new DateTime(date.Year, date.Month, date.Day, time.Hour, time.Minute, time.Second)`

---

## Formatting

### format-date()

Formats a date as a human-readable string using a picture string.

**Signature:** `format-date($value as xs:date?, $picture as xs:string, $language as xs:string?, $calendar as xs:string?, $place as xs:string?) as xs:string?`

```xpath
format-date(current-date(), "[MNn] [D], [Y]")
=> "March 19, 2026"

format-date(current-date(), "[D01]/[M01]/[Y]")
=> "19/03/2026"

format-date(current-date(), "[FNn], [MNn] [D]")
=> "Thursday, March 19"

format-date(current-date(), "[Y]-[M01]-[D01]")
=> "2026-03-19"
```

**Picture string components:**

| Component | Meaning | Example |
|-----------|---------|---------|
| `[Y]` | Year | 2026 |
| `[M]` | Month number | 3 |
| `[M01]` | Month zero-padded | 03 |
| `[MNn]` | Month name | March |
| `[D]` | Day | 19 |
| `[D01]` | Day zero-padded | 19 |
| `[FNn]` | Day of week name | Thursday |
| `[F1]` | Day of week number | 4 |

**C# equivalent:** `date.ToString("MMMM d, yyyy")` — but XPath's picture strings use a different syntax from .NET format strings.

---

### format-dateTime()

Formats a dateTime value.

**Signature:** `format-dateTime($value as xs:dateTime?, $picture as xs:string, ...) as xs:string?`

```xpath
format-dateTime(current-dateTime(), "[MNn] [D], [Y] at [h]:[m01] [PN]")
=> "March 19, 2026 at 2:30 PM"

format-dateTime(current-dateTime(), "[Y]-[M01]-[D01]T[H01]:[m01]:[s01]")
=> "2026-03-19T14:30:00"
```

**Additional components:**

| Component | Meaning | Example |
|-----------|---------|---------|
| `[H]` | Hour (24h) | 14 |
| `[H01]` | Hour zero-padded (24h) | 14 |
| `[h]` | Hour (12h) | 2 |
| `[m]` | Minute | 30 |
| `[m01]` | Minute zero-padded | 30 |
| `[s]` | Second | 0 |
| `[s01]` | Second zero-padded | 00 |
| `[PN]` | AM/PM | PM |
| `[Z]` | Timezone | -05:00 |
| `[ZN]` | Timezone name | EST |

---

### format-time()

Formats a time value.

```xpath
format-time(xs:time("14:30:00"), "[h]:[m01] [PN]")
=> "2:30 PM"

format-time(xs:time("09:05:30"), "[H01]:[m01]:[s01]")
=> "09:05:30"
```
