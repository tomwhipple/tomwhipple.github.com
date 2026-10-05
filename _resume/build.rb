#!/usr/bin/env ruby
# Renders hire.md to whipple_resume.pdf using kramdown (same as Jekyll) and headless Chrome.
# Usage: bundle exec ruby _resume/build.rb   (set CHROME=/path/to/chrome if not auto-detected)
require "kramdown"
require "yaml"
require "cgi"
require "tmpdir"

root = File.expand_path("..", __dir__)
src = File.read(File.join(root, "hire.md"), encoding: "utf-8")
_, front, body = src.split(/^---\s*$/, 3)
info = YAML.safe_load(front)["resume"]

html = Kramdown::Document.new(body, input: "GFM", hard_wrap: false).to_html
# Pair each "### Role" with the "#### Dates" that follows so they share a line.
html = html.gsub(%r{(<h3[^>]*>.*?</h3>)\s*(<h4[^>]*>.*?</h4>)}m, '<div class="role">\1\2</div>')

contact = info["contact"].map { |c| "<span>#{CGI.escapeHTML(c)}</span>" }.join
page = <<~HTML
  <!doctype html>
  <html><head><meta charset="utf-8"><title>#{info["name"]} - Resume</title>
  <style>#{File.read(File.join(__dir__, "resume.css"), encoding: "utf-8")}</style></head>
  <body>
  <header><h1>#{info["name"]}</h1>
  <div class="headline">#{info["headline"]}</div>
  <div class="contact">#{contact}</div></header>
  #{html}
  </body></html>
HTML

playwright = ENV["PLAYWRIGHT_BROWSERS_PATH"] ||
  File.expand_path(RUBY_PLATFORM.include?("darwin") ? "~/Library/Caches/ms-playwright" : "~/.cache/ms-playwright")
chrome = ENV["CHROME"] || [
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  *%w[google-chrome chromium chromium-browser].filter_map { |c| `command -v #{c}`.strip.then { |p| p unless p.empty? } },
  # Playwright's Chromium, newest revision first
  *Dir.glob("#{playwright}/chromium-*/chrome-*/{Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing,Chromium.app/Contents/MacOS/Chromium,chrome}")
      .sort_by { |p| -p[/chromium-(\d+)/, 1].to_i }
].find { |p| File.executable?(p) } or abort("Chrome not found; set CHROME=/path/to/chrome")

out = File.join(root, "whipple_resume.pdf")
Dir.mktmpdir do |dir|
  tmp = File.join(dir, "resume.html")
  File.write(tmp, page)
  File.write(File.join(root, "_resume", "resume.html"), page) if ENV["KEEP_HTML"]
  system(chrome, "--headless", "--disable-gpu", "--no-pdf-header-footer",
         "--print-to-pdf=#{out}", "file://#{tmp}", exception: true, err: File::NULL)
end
puts "Wrote #{out}"
