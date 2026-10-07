---
title: Hosting the Engines
description: Which thread your code continues on after an await, for server, desktop, plugin and browser hosts
sort: 7
---

# Hosting the Engines

The XSLT and XQuery APIs are asynchronous. This page covers what that means for the thread your
code is on after an `await`, which depends on the kind of host.

## What the engines do

**XSLT.** `XsltTransformer` compiles and transforms on a dedicated thread with a large stack, so
deeply recursive stylesheets don't overflow the default 1 MB stack. `TransformAsync` has done this
since before 2.5; **since 2.6.0, `LoadStylesheetAsync` does too.** Each task therefore completes on a
thread-pool thread, not on the thread that called it.

**XQuery.** The query engine doesn't start threads of its own, so a query normally completes on the
calling thread. A query that calls `fn:transform` runs the XSLT engine, as above.

Either way, standard .NET rules decide where your code resumes after `await`:

- If the calling thread has a `SynchronizationContext` (an ordinary WinForms or WPF app, a Blazor
  component), the continuation is posted back to it, so you're on the UI thread again.
- If it has none, the continuation runs wherever the task completed. For XSLT that's a thread-pool
  thread.

## Servers and web apps

ASP.NET Core has no `SynchronizationContext`, and you don't want one: resuming on the thread pool is
what keeps request threads free. Use the async methods as they are. Pass the request's
`CancellationToken`, and see [Resource Policy](resource-policy.md) and `RegexMatchTimeout` when the
stylesheets or queries aren't trusted.

## Desktop applications

A WinForms or WPF app that started with `Application.Run` has a UI context, so after
`await transformer.TransformAsync(...)` you're back on the UI thread and can update controls
directly. Don't block on the task (`.Result`, `.Wait()`) from the UI thread.

## Plugins and other hosts without a UI context

Some hosts call your code from a native message loop with no `SynchronizationContext`: editor
plugins (Notepad++ .NET plugins, for example), COM add-ins and some game or CAD hosts. There, after
`await LoadStylesheetAsync(...)` or `await TransformAsync(...)` your code is on a thread-pool (MTA)
thread. UI calls then misbehave: an `OpenFileDialog` doesn't appear, and editor updates race the UI.

- Do UI work such as file dialogs **before** the first `await`, while you're still on the UI thread.
- Marshal UI work after an `await` back to the UI thread explicitly, for example with
  `Control.Invoke` on a control owned by that thread.

```csharp
// Still on the UI thread: ask for the input first.
string? inputPath = PickInputFile();          // OpenFileDialog
if (inputPath is null) return;

var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(File.ReadAllText(xslPath), new Uri(xslPath));
transformer.SetSourceDocumentUri(new Uri(inputPath));
string result = await transformer.TransformAsync(File.ReadAllText(inputPath));

// Now on a thread-pool thread: hand the result back to the UI thread.
uiControl.Invoke(() => ShowResult(result));
```

**Since 2.7.0, the simpler route is the synchronous methods.** `LoadStylesheet` and `Transform`
block the calling thread and return on it, so a plugin never leaves its UI thread:

```csharp
var transformer = new XsltTransformer();
transformer.LoadStylesheet(File.ReadAllText(xslPath), new Uri(xslPath));
transformer.SetSourceDocumentUri(new Uri(inputPath));
string result = transformer.Transform(File.ReadAllText(inputPath));
ShowResult(result);   // still on the UI thread
```

The work still runs on the engine's large-stack thread, so deep recursion is as safe as with the
async methods. They are not available on browser WebAssembly, which cannot block
([phoenixmldb-xslt #309](https://github.com/phoenixmldb/phoenixmldb-xslt/issues/309)).

## Browser WebAssembly

Blazor WebAssembly has no threads, so the engines run inline on the browser's single thread and the
continuation stays there. Since 2.6.0 XSLT works in Blazor WebAssembly again, and deep recursion
there no longer exhausts the stack. A long transformation blocks the page while it runs.
