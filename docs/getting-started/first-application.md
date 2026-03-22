---
title: First Application
description: Build a complete library management app with PhoenixmlDb
sort: 3
---

# Building Your First Application

In this tutorial, we'll build a complete library management application using PhoenixmlDb. You'll learn how to design a document schema, create indexes, perform CRUD operations, and write complex queries.

## Project Setup

Create a new .NET console application:

```bash
dotnet new console -n LibraryApp
cd LibraryApp
dotnet add package PhoenixmlDb
```

## Document Design

Our library will manage books, members, and loans. Here are the document schemas:

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
using PhoenixmlDb;

public class LibraryDatabase : IDisposable
{
    private readonly XmlDatabase _db;

    public IContainer Books { get; }
    public IContainer Members { get; }
    public IContainer Loans { get; }

    public LibraryDatabase(string path)
    {
        _db = new XmlDatabase(path, new DatabaseOptions
        {
            MapSize = 1L * 1024 * 1024 * 1024 // 1 GB
        });

        // Create containers
        Books = _db.OpenOrCreateContainer("books");
        Members = _db.OpenOrCreateContainer("members");
        Loans = _db.OpenOrCreateContainer("loans");

        // Create indexes
        CreateIndexes();
    }

    private void CreateIndexes()
    {
        // Book indexes
        Books.CreateIndexIfNotExists(new PathIndex("isbn-idx", "/book/@isbn"));
        Books.CreateIndexIfNotExists(new ValueIndex("year-idx", "/book/year", ValueType.Integer));
        Books.CreateIndexIfNotExists(new FullTextIndex("title-idx", "/book/title"));
        Books.CreateIndexIfNotExists(new PathIndex("category-idx", "/book/categories/category"));

        // Member indexes
        Members.CreateIndexIfNotExists(new PathIndex("member-id-idx", "/member/@id"));
        Members.CreateIndexIfNotExists(new PathIndex("email-idx", "/member/email"));

        // Loan indexes
        Loans.CreateIndexIfNotExists(new PathIndex("loan-book-idx", "/loan/bookIsbn"));
        Loans.CreateIndexIfNotExists(new PathIndex("loan-member-idx", "/loan/memberId"));
        Loans.CreateIndexIfNotExists(new ValueIndex("due-date-idx", "/loan/dueDate", ValueType.Date));
    }

    public ITransaction BeginTransaction(bool readOnly = false)
        => _db.BeginTransaction(readOnly);

    public IQueryResult Query(string xquery, QueryParameters? parameters = null)
        => _db.Query(xquery, parameters);

    public T QuerySingle<T>(string xquery, QueryParameters? parameters = null)
        => _db.QuerySingle<T>(xquery, parameters);

    public void Dispose() => _db.Dispose();
}
```

### Book Service

```csharp
// BookService.cs
public class BookService
{
    private readonly LibraryDatabase _db;

    public BookService(LibraryDatabase db) => _db = db;

    public void AddBook(Book book)
    {
        var xml = $"""
            <book isbn="{book.Isbn}">
                <title>{book.Title}</title>
                <authors>
                    {string.Join("\n", book.Authors.Select(a => $"<author>{a}</author>"))}
                </authors>
                <publisher>{book.Publisher}</publisher>
                <year>{book.Year}</year>
                <categories>
                    {string.Join("\n", book.Categories.Select(c => $"<category>{c}</category>"))}
                </categories>
                <copies>
                    {string.Join("\n", book.CopyIds.Select(id => $"<copy id=\"{id}\" status=\"available\"/>"))}
                </copies>
            </book>
            """;

        _db.Books.PutDocument($"{book.Isbn}.xml", xml);
    }

    public Book? GetBook(string isbn)
    {
        var results = _db.Query($"""
            collection('books')/book[@isbn='{isbn}']
            """);

        var xml = results.FirstOrDefault();
        return xml != null ? ParseBook(xml) : null;
    }

    public IEnumerable<Book> SearchBooks(string titleSearch)
    {
        var results = _db.Query("""
            for $b in collection('books')//book
            where contains(lower-case($b/title), lower-case($search))
            order by $b/title
            return $b
            """,
            new QueryParameters { ["search"] = titleSearch });

        return results.Select(ParseBook);
    }

    public IEnumerable<Book> GetBooksByCategory(string category)
    {
        var results = _db.Query("""
            for $b in collection('books')//book
            where $b/categories/category = $category
            order by $b/title
            return $b
            """,
            new QueryParameters { ["category"] = category });

        return results.Select(ParseBook);
    }

    public IEnumerable<Book> GetBooksByYearRange(int fromYear, int toYear)
    {
        var results = _db.Query("""
            for $b in collection('books')//book
            where $b/year >= $from and $b/year <= $to
            order by $b/year descending, $b/title
            return $b
            """,
            new QueryParameters
            {
                ["from"] = fromYear,
                ["to"] = toYear
            });

        return results.Select(ParseBook);
    }

    public void UpdateCopyStatus(string isbn, string copyId, string status)
    {
        using var txn = _db.BeginTransaction();

        // Use XQuery Update to modify the document
        txn.Execute($"""
            let $book := collection('books')/book[@isbn='{isbn}']
            let $copy := $book/copies/copy[@id='{copyId}']
            return replace value of node $copy/@status with '{status}'
            """);

        txn.Commit();
    }

    private static Book ParseBook(string xml)
    {
        var doc = XDocument.Parse(xml);
        var book = doc.Root!;

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
public class LoanService
{
    private readonly LibraryDatabase _db;
    private readonly BookService _bookService;

    public LoanService(LibraryDatabase db, BookService bookService)
    {
        _db = db;
        _bookService = bookService;
    }

    public string CheckoutBook(string isbn, string copyId, string memberId, int loanDays = 14)
    {
        using var txn = _db.BeginTransaction();

        // Verify book and copy exist and are available
        var available = txn.QuerySingle<bool>($"""
            exists(collection('books')/book[@isbn='{isbn}']
                /copies/copy[@id='{copyId}'][@status='available'])
            """);

        if (!available)
            throw new InvalidOperationException("Book copy not available");

        // Create loan
        var loanId = $"L{DateTime.UtcNow:yyyyMMddHHmmss}";
        var loanDate = DateTime.UtcNow.Date;
        var dueDate = loanDate.AddDays(loanDays);

        var loanXml = $"""
            <loan id="{loanId}">
                <bookIsbn>{isbn}</bookIsbn>
                <copyId>{copyId}</copyId>
                <memberId>{memberId}</memberId>
                <loanDate>{loanDate:yyyy-MM-dd}</loanDate>
                <dueDate>{dueDate:yyyy-MM-dd}</dueDate>
                <returnDate/>
            </loan>
            """;

        txn.GetContainer("loans").PutDocument($"{loanId}.xml", loanXml);

        // Update copy status
        txn.Execute($"""
            let $copy := collection('books')/book[@isbn='{isbn}']
                /copies/copy[@id='{copyId}']
            return replace value of node $copy/@status with 'loaned'
            """);

        txn.Commit();
        return loanId;
    }

    public void ReturnBook(string loanId)
    {
        using var txn = _db.BeginTransaction();

        // Get loan details
        var loan = txn.Query($"collection('loans')/loan[@id='{loanId}']").FirstOrDefault()
            ?? throw new InvalidOperationException("Loan not found");

        var loanDoc = XDocument.Parse(loan);
        var isbn = loanDoc.Root!.Element("bookIsbn")!.Value;
        var copyId = loanDoc.Root!.Element("copyId")!.Value;

        // Update loan with return date
        txn.Execute($"""
            let $loan := collection('loans')/loan[@id='{loanId}']
            return replace value of node $loan/returnDate with '{DateTime.UtcNow:yyyy-MM-dd}'
            """);

        // Update copy status
        txn.Execute($"""
            let $copy := collection('books')/book[@isbn='{isbn}']
                /copies/copy[@id='{copyId}']
            return replace value of node $copy/@status with 'available'
            """);

        txn.Commit();
    }

    public IEnumerable<LoanInfo> GetOverdueLoans()
    {
        var today = DateTime.UtcNow.Date.ToString("yyyy-MM-dd");

        var results = _db.Query($"""
            for $loan in collection('loans')//loan
            where $loan/returnDate = '' and $loan/dueDate < '{today}'
            let $book := collection('books')/book[@isbn = $loan/bookIsbn]
            let $member := collection('members')/member[@id = $loan/memberId]
            order by $loan/dueDate
            return <overdue>
                <loanId>{{$loan/@id/string()}}</loanId>
                <bookTitle>{{$book/title/text()}}</bookTitle>
                <memberName>{{concat($member/name/first, ' ', $member/name/last)}}</memberName>
                <dueDate>{{$loan/dueDate/text()}}</dueDate>
                <daysOverdue>{{days-from-duration(current-date() - xs:date($loan/dueDate))}}</daysOverdue>
            </overdue>
            """);

        return results.Select(xml =>
        {
            var doc = XDocument.Parse(xml);
            return new LoanInfo
            {
                LoanId = doc.Root!.Element("loanId")!.Value,
                BookTitle = doc.Root!.Element("bookTitle")!.Value,
                MemberName = doc.Root!.Element("memberName")!.Value,
                DueDate = DateTime.Parse(doc.Root!.Element("dueDate")!.Value),
                DaysOverdue = int.Parse(doc.Root!.Element("daysOverdue")!.Value)
            };
        });
    }

    public IEnumerable<LoanInfo> GetMemberLoans(string memberId)
    {
        var results = _db.Query("""
            for $loan in collection('loans')//loan
            where $loan/memberId = $memberId and $loan/returnDate = ''
            let $book := collection('books')/book[@isbn = $loan/bookIsbn]
            order by $loan/dueDate
            return <loan>
                <loanId>{$loan/@id/string()}</loanId>
                <bookTitle>{$book/title/text()}</bookTitle>
                <dueDate>{$loan/dueDate/text()}</dueDate>
            </loan>
            """,
            new QueryParameters { ["memberId"] = memberId });

        return results.Select(xml =>
        {
            var doc = XDocument.Parse(xml);
            return new LoanInfo
            {
                LoanId = doc.Root!.Element("loanId")!.Value,
                BookTitle = doc.Root!.Element("bookTitle")!.Value,
                DueDate = DateTime.Parse(doc.Root!.Element("dueDate")!.Value)
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
using var db = new LibraryDatabase("./library-data");
var bookService = new BookService(db);
var loanService = new LoanService(db, bookService);

// Add some books
bookService.AddBook(new Book
{
    Isbn = "978-0-13-468599-1",
    Title = "The Pragmatic Programmer",
    Authors = ["David Thomas", "Andrew Hunt"],
    Publisher = "Addison-Wesley",
    Year = 2019,
    Categories = ["Programming", "Software Engineering"],
    CopyIds = ["C001", "C002"]
});

bookService.AddBook(new Book
{
    Isbn = "978-0-596-51774-8",
    Title = "JavaScript: The Good Parts",
    Authors = ["Douglas Crockford"],
    Publisher = "O'Reilly",
    Year = 2008,
    Categories = ["Programming", "JavaScript"],
    CopyIds = ["C003"]
});

// Search for books
Console.WriteLine("=== Search Results ===");
foreach (var book in bookService.SearchBooks("pragmatic"))
{
    Console.WriteLine($"{book.Title} ({book.Year})");
}

// Checkout a book
var loanId = loanService.CheckoutBook(
    isbn: "978-0-13-468599-1",
    copyId: "C001",
    memberId: "M001");
Console.WriteLine($"\nBook checked out. Loan ID: {loanId}");

// Check overdue loans
Console.WriteLine("\n=== Overdue Loans ===");
foreach (var loan in loanService.GetOverdueLoans())
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
3. **Transactions**: Use transactions for multi-document operations
4. **XQuery**: Leverage XQuery's power for complex queries and joins
5. **Parameterized Queries**: Always use parameters to prevent injection

## Next Steps

| Architecture | Querying | Performance |
|---|---|---|
| **[Core Concepts](../concepts/core-concepts.md)**<br>Deep dive into PhoenixmlDb architecture | **[XQuery Guide](../xquery/xquery-guide.md)**<br>Master XQuery for complex queries | **[Indexing](../reference/indexing.md)**<br>Optimize query performance |
