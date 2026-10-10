# CDR Viewer

A small Rails app that imports call detail records (CDRs) from a CSV and shows
them in a table you can filter by date.

I built it to get a feel for the problem: real CDR exports are rarely clean, so
most of the interesting work is in the importer, not the table.

## What it does

- Imports a CSV of calls: date/time, from number, to number, duration, cell tower ID
- Shows the calls in a table, filterable by a from/to date range
- Reports every row it could not import, with the line number and the reason

## Running it

Requires Ruby 3.4 and SQLite.

```sh
bin/setup --skip-server   # install gems, create the database
bin/rails db:seed         # load the sample file (19 calls imported, 8 rows rejected)
bin/rails server          # http://localhost:3000
```

Import a file from the page, or from the command line:

```sh
bin/rails 'cdr:import[db/sample/calls.csv]'
```

Run the tests with `bin/rails test`.

## How the importer handles messy rows

The sample file, [db/sample/calls.csv](db/sample/calls.csv), is deliberately
messy. The rule the importer follows: fix a row when the intent is
unambiguous, reject it with a reason when it is not, and never let one bad row
stop the rest of the file.

| In the file | What happens |
| --- | --- |
| `(202) 555-0142`, `202.555.0177`, `+1 202 555 0101` | Normalised to `+12025550142` style, so the same phone always matches |
| `03/02/2026 2:15 PM`, `2026-03-03T09:12:00Z` | Parsed; several timestamp formats are accepted |
| `2:05`, `00:10:30` | Converted to seconds |
| Extra spaces, `twr-0007` | Trimmed; tower IDs upper-cased |
| Blank line | Skipped |
| No tower ID | Imported with the tower shown as "unknown" |
| Duration `0` | Imported (an unanswered call is still a call) |
| The same call twice | Second copy rejected, even if formatted differently |
| `2026-02-30`, `yesterday afternoon` | Rejected: not a real date/time |
| `555-0101` | Rejected: not a full 10-digit number |
| Duration `-30`, `a few minutes` | Rejected |
| Missing from/to number, truncated row | Rejected |

A missing column or an unreadable file fails the whole import and saves
nothing, since guessing which column is which would be worse than stopping.

The code is in [app/services/cdr_importer.rb](app/services/cdr_importer.rb) and
its tests in [test/services/cdr_importer_test.rb](test/services/cdr_importer_test.rb).

## Assumptions and limits

- Phone numbers are North American (10 digits, optional leading 1).
- Timestamps with no time zone are treated as UTC, and the table shows UTC.
- A call is identified by its start time plus both numbers; importing the same
  file twice adds nothing.
- Rows are inserted one at a time, which is fine for small files. A real CDR
  feed would need batched inserts and a background job.
- The table shows at most 500 rows; there is no pagination.

All phone numbers in the sample data are fictional (555-01xx).
