# AGENTS.md

Jekyll site for tomwhipple.com (minima theme). Notes for humans and AI agents.

## Resume

`hire.md` is the single source for both the /hire/ web page and the PDF resume (`whipple_resume.pdf`). Edit content there only.

### Build the PDF

```sh
bundle exec ruby _resume/build.rb
```

- Ruby version is pinned in `.tool-versions` (asdf). First time: `asdf install && bundle install`.
- Overwrites `whipple_resume.pdf` at the repo root. Commit it with the `hire.md` change.
- Uses kramdown (GFM, same as Jekyll) to render, then headless Chrome to print.
- Chrome, Chromium, or Playwright's Chromium is auto-detected on macOS/Linux; otherwise set `CHROME=/path/to/chrome`.
- `KEEP_HTML=1` also writes `_resume/resume.html` for debugging the layout.

### Conventions in `hire.md`

- `resume:` front matter (name, headline, contact list) builds the PDF header only; it isn't shown on the site.
- `## Section` (or Setext `---` underline) becomes a section rule.
- `### Title, [Company](url)` followed by `#### Dates` renders as one line with dates right-aligned. Keep that pairing.
- Add `{: .web-only}` on the line after a block to show it on the site but hide it in the PDF.
- Target two pages max; check page count after edits (e.g. `pdfinfo whipple_resume.pdf`).

### Styling

`_resume/resume.css` controls the PDF look (Charter font, Letter page, margins). `_resume/` is ignored by Jekyll.
