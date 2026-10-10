# CDR Viewer

A small Rails app that imports call detail records (CDRs) from a CSV and shows
them in a table you can filter by date.

I built it to get a feel for the problem: real CDR exports are rarely clean, so
most of the interesting work is in the importer, not the table.

## What it does

- Imports a CSV of calls: date/time, from number, to number, duration, cell tower ID
- Recognises two column layouts and refuses any other, rather than guessing
- Shows the calls in a table, filterable by a from/to date range
- Reports every row it could not import, with the line number and the reason
- Keeps a record of every file received, so any call can be traced back to the
  file and line it came from

## Running it

Requires Ruby 3.4 and SQLite.

```sh
bin/setup --skip-server   # install gems, create the database
bin/rails db:seed         # load the two sample files (25 calls imported, 10 rows rejected)
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
| The same call twice | Second copy rejected, even if formatted differently, naming the file and line of the first |
| `2026-02-30`, `yesterday afternoon` | Rejected: not a real date/time |
| `555-0101` | Rejected: not a full 10-digit number |
| Duration `-30`, `a few minutes` | Rejected |
| Missing from/to number, truncated row | Rejected |

An unreadable file fails the whole import and saves nothing.

## Column layouts

Different sources name and arrange the same data differently, and layouts
change without notice. The importer keeps a small table of the layouts it
knows, `LAYOUTS` in the importer, and picks one by looking at the header row:

| Layout | Columns |
| --- | --- |
| `standard` | `timestamp`, `from_number`, `to_number`, `duration`, `cell_tower_id` |
| `split_datetime` | `Call Date`, `Call Time`, `Calling Party`, `Called Party`, `Duration (sec)`, `Site ID` |

Both are invented for this project; they are not real carrier formats. There
is a sample of the second in
[db/sample/calls_split_datetime.csv](db/sample/calls_split_datetime.csv).

- Column order, header capitalisation, stray spaces and extra columns do not
  matter.
- If the header fits no known layout, or fits more than one, the whole file is
  refused with a message listing the columns found and the layouts known.
  Guessing which column is the caller and which is the callee could produce
  records that look right and are wrong, which is worse than stopping.
- The layout a file was read as is saved on its import record.
- The same call arriving in both layouts is still caught as a duplicate,
  because rows are compared after normalising, not as text.

Supporting a new layout means adding one entry to `LAYOUTS` and a test.

The code is in [app/services/cdr_importer.rb](app/services/cdr_importer.rb) and
its tests in [test/services/cdr_importer_test.rb](test/services/cdr_importer_test.rb).

## Tracing a call back to its source

If what the app shows might be relied on, it has to be possible to say where
each row came from and to show that nothing was quietly dropped.

- Every upload is recorded on the Imports page with its file name, size, time
  received and a SHA-256 fingerprint of the bytes exactly as received. This
  includes files that fail and files that have been uploaded before.
- Every call stores the import it came from and its line number in that file,
  shown in the table as `calls.csv:14`.
- Every rejected row is saved with its line number, the reason, and the text
  as it appears in the file, not a tidied-up copy.
- Uploading a byte-identical file again adds no calls; its report links to the
  earlier upload with the same fingerprint.

Line numbers are counted from the raw file, so they match what you see when
you open it. Ruby's CSV parser numbers rows instead, which drifts after a blank
line or a quoted field containing a line break. A test caught this.

## Assumptions and limits

- Phone numbers are North American (10 digits, optional leading 1).
- Timestamps with no time zone are treated as UTC, and the table shows UTC.
- A call is identified by its start time plus both numbers; importing the same
  file twice adds nothing.
- Rows are inserted one at a time, which is fine for small files. A real CDR
  feed would need batched inserts and a background job.
- The table shows at most 500 rows; there is no pagination.
- Only the fingerprint of an uploaded file is kept, not the file. A real system
  would also store the original, unmodified, in object storage.
- There are no user accounts, so an import does not record who uploaded it.

All phone numbers in the sample data are fictional (555-01xx).
