"""
Verify docs/paper/smartlocker-10p.pdf:
1. Page count
2. Check for '??' undefined references
3. Check Page 1 author block and text
4. Render all pages to PNG
"""
import os
import sys
import fitz  # PyMuPDF

pdf_path = os.path.join(os.path.dirname(__file__), "..", "smartlocker-10p.pdf")
if not os.path.exists(pdf_path):
    print(f"Error: PDF not found at {pdf_path}")
    sys.exit(1)

doc = fitz.open(pdf_path)
page_count = len(doc)
print(f"Total pages: {page_count}")

undefined_refs = []
page1_text = ""

for i in range(page_count):
    page = doc[i]
    text = page.get_text()
    if i == 0:
        page1_text = text
    if "??" in text:
        undefined_refs.append(i + 1)

print("\n--- Page 1 Snippet (Author Block) ---")
lines = page1_text.splitlines()[:25]
for line in lines:
    print(f"  {line}")

print("\n--- Undefined References ('??') ---")
if undefined_refs:
    print(f"Found on pages: {undefined_refs}")
else:
    print("None! All references resolved cleanly.")

out_dir = os.path.join(os.path.dirname(__file__), "..", "rendered_pages")
os.makedirs(out_dir, exist_ok=True)

for i in range(page_count):
    page = doc[i]
    pix = page.get_pixmap(dpi=150)
    out_file = os.path.join(out_dir, f"page-{i+1}.png")
    pix.save(out_file)
    print(f"Saved {out_file} ({pix.width}x{pix.height})")

print(f"\nAll {page_count} pages successfully rendered to {out_dir}")
