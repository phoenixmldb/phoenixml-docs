---
title: First Application
description: Build a complete library management app with PhoenixmlDb
sort: 3
---

# Building Your First Application

In this tutorial, we'll build a complete library management application using PhoenixmlDb. You'll learn how to design a document schema, create indexes, perform CRUD operations, and write complex queries.

## Project Setup

> **Note:** The PhoenixmlDb database packages are not yet published on NuGet, so the
> `dotnet add package` lines below will not resolve until they are.

Create a new .NET console application:

```bash
dotnet new console -n LibraryApp
cd LibraryApp
dotnet add package PhoenixmlDb.Storage
dotnet add package PhoenixmlDb.Indexing
```

## Document Design

Our library will manage books, members, and loans. All three kinds of document live in one
container, `library`, because a query's `collection()` spans only the container it runs
against; that lets a single XQuery join books, members and loans. Here are the document schemas:

### Book Document

```xml
<book isbn="978-0-13-468599-1">
    <title>The Pragmatic Programmer</title>
    <authors>
        <author>David Thomas</author>
        <author>Andrew Hunt</author>
    </authors>
    <publisher>Addison-Wesley</publisher>
    <year>2019</year>
    <categories>
        <category>Programming</category>
        <category>Software Engineering</category>
    </categories>
    <copies>
        <copy id="C001" status="available"/>
        <copy id="C002" status="loaned"/>
    </copies>
</book>
```

### Member Document

```xml
<member id="M001">
    <name>
        <first>Jane</first>
        <last>Smith</last>
    </name>
    <email>jane.smith@email.com</email>
    <memberSince>2023-01-15</memberSince>
    <memberType>premium</memberType>
</member>
```

### Loan Document

```xml
<loan id="L001">
    <bookIsbn>978-0-13-468599-1</bookIsbn>
    <copyId>C002</copyId>
    <memberId>M001</memberId>
    <loanDate>2024-01-10</loanDate>
    <dueDate>2024-01-24</dueDate>
    <returnDate/>
</loan>
```

## Application Code

### Database Initialization

```csharp
// LibraryDatabase.cs
using PhoenixmlDb.Core;
using PhoenixmlDb.Indexing;
using PhoenixmlDb.Storage;
using PhoenixmlDb.Storage.Lmdb;

public sealed class LibraryDatabase : IDisposable
{
    private readonly DocumentDatabase _db;

    private LibraryDatabase(DocumentDatabase db, IContainer library)
    {
        _db = db;
        Library = library;
    }

    public IContainer Library { get; }

    public static async Task<LibraryDatabase> OpenAsync(string path)
    {
        var db = new DocumentDatabase(path, new LmdbStorageOptions
        {
            MapSize = 1L * 1024 * 1024 * 1024 // 1 GB
        });

        try
        {
            // Index maintenance is opt-in
            db.EnableIndexing();

            // Indexes are declared when the container is created; on later runs the
            // existing container is opened and this callback is not invoked.
            var library = await db.OpenOrCreateContainerAsync("library", opts =>
            {
                // Book indexes
                opts.Indexes.AddValueIndex("/book/@isbn", XdmValueType.XdmString);
                opts.Indexes.AddValueIndex("/book/year", XdmValueType.XdmInteger);
                opts.Indexes.AddFullTextIndex("/book/title");
                opts.Indexes.AddPathIndex("/book/categories/category");

                // Member indexes
                opts.Indexes.AddValueIndex("/member/@id", XdmValueType.XdmString);
                opts.Indexes.AddPathIndex("/member/email");

                // Loan indexes
                opts.Indexes.AddValueIndex("/loan/bookIsbn", XdmValueType.XdmString);
                opts.Indexes.AddValueIndex("/loan/memberId", XdmValueType.XdmString);
                opts.Indexes.AddValueIndex("/loan/dueDate", XdmValueType.Date);
            });

            return new LibraryDatabase(db, library);
        }
        catch
        {
            db.Dispose();
            throw;
        }
    }

    public ValueTask<IWriteTransaction> BeginWriteAsync() => _db.BeginWriteAsync();

    public async Task<List<string>> QueryAsync(
        string xquery, IReadOnlyDictionary<string, object>? variables = null)
    {
        var results = new List<string>();
        await foreach (var item in Library.QueryAsync(xquery, variables))
            results.Add(item.ToString()!);
        return results;
    }

    public void Dispose() => _db.Dispose();
}
```

### Book Service

```csharp
// BookService.cs
using System.Xml.Linq;

public class BookService
{
    private readonly LibraryDatabase _db;

    public BookService(LibraryDatabase db) => _db = db;

    public static string DocumentName(string isbn) => $"book-{isbn}.xml";

    public async Task AddBookAsync(Book book)
    {
        var xml = new XElement("book",
            new XAttribute("isbn", book.Isbn),
            new XElement("title", book.Title),
            new XElement("authors", book.Authors.Select(a => new XElement("author", a))),
            new XElement("publisher", book.Publisher),
            new XElement("year", book.Year),
            new XElement("categories", book.Categories.Select(c => new XElement("category", c))),
            new XElement("copies", book.CopyIds.Select(id =>
                new XElement("copy", new XAttribute("id", id), new XAttribute("status", "available")))));

        await _db.Library.PutDocumentAsync(DocumentName(book.Isbn), xml.ToString());
    }

    public async Task<Book?> GetBookAsync(string isbn)
    {
        var results = await _db.QueryAsync("""
            declare variable $isbn external;
            collection()/book[@isbn = $isbn]
            """,
            new Dictionary<string, object> { ["isbn"] = isbn });

        return results.Count > 0 ? ParseBook(results[0]) : null;
    }

    public async Task<IEnumerable<Book>> SearchBooksAsync(string titleSearch)
    {
        var results = await _db.QueryAsync("""
            declare variable $search external;
            for $b in collection()/book
            where contains(lower-case($b/title), lower-case($search))
            order by $b/title
            return $b
            """,
            new Dictionary<string, object> { ["search"] = titleSearch });

        return results.Select(ParseBook);
    }

    public async Task<IEnumerable<Book>> GetBooksByCategoryAsync(string category)
    {
        var results = await _db.QueryAsync("""
            declare variable $category external;
            for $b in collection()/book
            where $b/categories/category = $category
            order by $b/title
            return $b
            """,
            new Dictionary<string, object> { ["category"] = category });

        return results.Select(ParseBook);
    }

    public async Task<IEnumerable<Book>> GetBooksByYearRangeAsync(int fromYear, int toYear)
    {
        var results = await _db.QueryAsync("""
            declare variable $from external;
            declare variable $to external;
            for $b in collection()/book
            where xs:integer($b/year) >= $from and xs:integer($b/year) <= $to
            order by xs:integer($b/year) descending, $b/title
            return $b
            """,
            new Dictionary<string, object>
            {
                ["from"] = fromYear,
                ["to"] = toYear
            });

        return results.Select(ParseBook);
    }

    public async Task UpdateCopyStatusAsync(string isbn, string copyId, string status)
    {
        await using var txn = await _db.BeginWriteAsync();
        var containerId = _db.Library.Id;

        // Read the current document, change it, and write it back under the same name
        var doc = await txn.GetDocumentAsync(containerId, DocumentName(isbn))
            ?? throw new InvalidOperationException("Book not found");
        var book = XDocument.Parse(await doc.GetContentAsync());

        var copy = FindCopy(book, copyId)
            ?? throw new InvalidOperationException("Copy not found");
        copy.SetAttributeValue("status", status);

        await txn.PutDocumentAsync(containerId, DocumentName(isbn), book.Root!.ToString());
        await txn.CommitAsync();
    }

    public static XElement? FindCopy(XDocument book, string copyId) =>
        book.Root!.Element("copies")!.Elements("copy")
            .FirstOrDefault(c => (string?)c.Attribute("id") == copyId);

    private static Book ParseBook(string xml)
    {
        var book = XElement.Parse(xml);

        return new Book
        {
            Isbn = book.Attribute("isbn")!.Value,
            Title = book.Element("title")!.Value,
            Authors = book.Element("authors")!.Elements("author").Select(e => e.Value).ToList(),
            Publisher = book.Element("publisher")!.Value,
            Year = int.Parse(book.Element("year")!.Value),
            Categories = book.Element("categories")!.Elements("category").Select(e => e.Value).ToList(),
            CopyIds = book.Element("copies")!.Elements("copy").Select(e => e.Attribute("id")!.Value).ToList()
        };
    }
}

public record Book
{
    public required string Isbn { get; init; }
    public required string Title { get; init; }
    public required List<string> Authors { get; init; }
    public required string Publisher { get; init; }
    public required int Year { get; init; }
    public required List<string> Categories { get; init; }
    public required List<string> CopyIds { get; init; }
}
```

### Loan Service

```csharp
// LoanService.cs
using System.Xml.Linq;

public class LoanService
{
    private readonly LibraryDatabase _db;

    public LoanService(LibraryDatabase db) => _db = db;

    public static string DocumentName(string loanId) => $"loan-{loanId}.xml";

    public async Task<string> CheckoutBookAsync(
        string isbn, string copyId, string memberId, int loanDays = 14)
    {
        await using var txn = await _db.BeginWriteAsync();
        var containerId = _db.Library.Id;
        var bookName = BookService.DocumentName(isbn);

        // Verify book and copy exist and are available
        var bookDoc = await txn.GetDocumentAsync(containerId, bookName)
            ?? throw new InvalidOperationException("Book not found");
        var book = XDocument.Parse(await bookDoc.GetContentAsync());
        var copy = BookService.FindCopy(book, copyId);

        if (copy is null || (string?)copy.Attribute("status") != "available")
            throw new InvalidOperationException("Book copy not available");

        // Create loan
        var loanId = $"L{DateTime.UtcNow:yyyyMMddHHmmss}";
        var loanDate = DateTime.UtcNow.Date;
        var dueDate = loanDate.AddDays(loanDays);

        var loan = new XElement("loan",
            new XAttribute("id", loanId),
            new XElement("bookIsbn", isbn),
            new XElement("copyId", copyId),
            new XElement("memberId", memberId),
            new XElement("loanDate", loanDate.ToString("yyyy-MM-dd")),
            new XElement("dueDate", dueDate.ToString("yyyy-MM-dd")),
            new XElement("returnDate"));

        await txn.PutDocumentAsync(containerId, DocumentName(loanId), loan.ToString());

        // Update copy status
        copy.SetAttributeValue("status", "loaned");
        await txn.PutDocumentAsync(containerId, bookName, book.Root!.ToString());

        // Both writes are applied atomically
        await txn.CommitAsync();
        return loanId;
    }

    public async Task ReturnBookAsync(string loanId)
    {
        await using var txn = await _db.BeginWriteAsync();
        var containerId = _db.Library.Id;

        // Get loan details
        var loanDoc = await txn.GetDocumentAsync(containerId, DocumentName(loanId))
            ?? throw new InvalidOperationException("Loan not found");
        var loan = XDocument.Parse(await loanDoc.GetContentAsync());
        var isbn = loan.Root!.Element("bookIsbn")!.Value;
        var copyId = loan.Root!.Element("copyId")!.Value;

        // Update loan with return date
        loan.Root!.Element("returnDate")!.Value = DateTime.UtcNow.ToString("yyyy-MM-dd");
        await txn.PutDocumentAsync(containerId, DocumentName(loanId), loan.Root!.ToString());

        // Update copy status
        var bookName = BookService.DocumentName(isbn);
        var bookDoc = await txn.GetDocumentAsync(containerId, bookName)
            ?? throw new InvalidOperationException("Book not found");
        var book = XDocument.Parse(await bookDoc.GetContentAsync());
        BookService.FindCopy(book, copyId)?.SetAttributeValue("status", "available");
        await txn.PutDocumentAsync(containerId, bookName, book.Root!.ToString());

        await txn.CommitAsync();
    }

    public async Task<IEnumerable<LoanInfo>> GetOverdueLoansAsync()
    {
        var results = await _db.QueryAsync("""
            for $loan in collection()/loan
            where $loan/returnDate = '' and xs:date($loan/dueDate) < current-date()
            let $book := collection()/book[@isbn = $loan/bookIsbn]
            let $member := collection()/member[@id = $loan/memberId]
            order by $loan/dueDate
            return <overdue>
                <loanId>{$loan/@id/string()}</loanId>
                <bookTitle>{$book/title/text()}</bookTitle>
                <memberName>{concat($member/name/first, ' ', $member/name/last)}</memberName>
                <dueDate>{$loan/dueDate/text()}</dueDate>
                <daysOverdue>{days-from-duration(current-date() - xs:date($loan/dueDate))}</daysOverdue>
            </overdue>
            """);

        return results.Select(xml =>
        {
            var overdue = XElement.Parse(xml);
            return new LoanInfo
            {
                LoanId = overdue.Element("loanId")!.Value,
                BookTitle = overdue.Element("bookTitle")!.Value,
                MemberName = overdue.Element("memberName")!.Value,
                DueDate = DateTime.Parse(overdue.Element("dueDate")!.Value),
                DaysOverdue = int.Parse(overdue.Element("daysOverdue")!.Value)
            };
        });
    }

    public async Task<IEnumerable<LoanInfo>> GetMemberLoansAsync(string memberId)
    {
        var results = await _db.QueryAsync("""
            declare variable $memberId external;
            for $loan in collection()/loan
            where $loan/memberId = $memberId and $loan/returnDate = ''
            let $book := collection()/book[@isbn = $loan/bookIsbn]
            order by $loan/dueDate
            return <loan>
                <loanId>{$loan/@id/string()}</loanId>
                <bookTitle>{$book/title/text()}</bookTitle>
                <dueDate>{$loan/dueDate/text()}</dueDate>
            </loan>
            """,
            new Dictionary<string, object> { ["memberId"] = memberId });

        return results.Select(xml =>
        {
            var loan = XElement.Parse(xml);
            return new LoanInfo
            {
                LoanId = loan.Element("loanId")!.Value,
                BookTitle = loan.Element("bookTitle")!.Value,
                DueDate = DateTime.Parse(loan.Element("dueDate")!.Value)
            };
        });
    }
}

public record LoanInfo
{
    public required string LoanId { get; init; }
    public required string BookTitle { get; init; }
    public string? MemberName { get; init; }
    public required DateTime DueDate { get; init; }
    public int DaysOverdue { get; init; }
}
```

### Main Program

```csharp
// Program.cs
using var db = await LibraryDatabase.OpenAsync("./library-data");
var bookService = new BookService(db);
var loanService = new LoanService(db);

// Add some books
await bookService.AddBookAsync(new Book
{
    Isbn = "978-0-13-468599-1",
    Title = "The Pragmatic Programmer",
    Authors = ["David Thomas", "Andrew Hunt"],
    Publisher = "Addison-Wesley",
    Year = 2019,
    Categories = ["Programming", "Software Engineering"],
    CopyIds = ["C001", "C002"]
});

await bookService.AddBookAsync(new Book
{
    Isbn = "978-0-596-51774-8",
    Title = "JavaScript: The Good Parts",
    Authors = ["Douglas Crockford"],
    Publisher = "O'Reilly",
    Year = 2008,
    Categories = ["Programming", "JavaScript"],
    CopyIds = ["C003"]
});

// Add a member
await db.Library.PutDocumentAsync("member-M001.xml", """
    <member id="M001">
        <name><first>Jane</first><last>Smith</last></name>
        <email>jane.smith@email.com</email>
        <memberSince>2023-01-15</memberSince>
        <memberType>premium</memberType>
    </member>
    """);

// Search for books
Console.WriteLine("=== Search Results ===");
foreach (var book in await bookService.SearchBooksAsync("pragmatic"))
{
    Console.WriteLine($"{book.Title} ({book.Year})");
}

// Checkout a book
var loanId = await loanService.CheckoutBookAsync(
    isbn: "978-0-13-468599-1",
    copyId: "C001",
    memberId: "M001");
Console.WriteLine($"\nBook checked out. Loan ID: {loanId}");

// Check overdue loans
Console.WriteLine("\n=== Overdue Loans ===");
foreach (var loan in await loanService.GetOverdueLoansAsync())
{
    Console.WriteLine($"{loan.BookTitle} - {loan.DaysOverdue} days overdue");
}
```

## Running the Application

```bash
dotnet run
```

## Key Takeaways

1. **Document Design**: Design documents that capture entity relationships naturally in XML
2. **Indexes**: Create indexes on frequently queried paths for performance
3. **Transactions**: Use a write transaction to apply multi-document changes atomically
4. **XQuery**: Leverage XQuery's power for complex queries and joins
5. **Parameterized Queries**: Always use parameters to prevent injection

## Next Steps

| Architecture | Querying | Performance |
|---|---|---|
| **[Core Concepts](../phoenixmldb/core-concepts.md)**<br>Deep dive into PhoenixmlDb architecture | **[XQuery Guide](../language-reference/xquery/index.md)**<br>Master XQuery for complex queries | **[Indexing](../phoenixmldb/indexing.md)**<br>Optimize query performance |
