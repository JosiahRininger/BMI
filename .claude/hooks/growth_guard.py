#!/usr/bin/env python3
"""Growth guard (GROWTH-AUTOMATION.md, section 4, item 4).

pre:  blocks a tool call that would submit for review, release a version, reply
      to a review, change a price or send an email, unless growth/approvals/<kind>.ok
      exists. Each approval file names the exact change Josiah approved; delete it
      once used.
post: appends every App Store Connect write (POST, PATCH, DELETE) to growth/audit.log.
"""
import datetime
import json
import os
import re
import sys

ROOT = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
GUARDED = {
    "submit": r"reviewSubmissions|\bsubmitted\b['\"]?\s*[:=]\s*true|submit_for_review",
    "release": r"appStoreVersionReleaseRequests|phasedReleases?",
    "review-reply": r"customerReviewResponses",
    "price": r"appPriceSchedules|inAppPurchasePriceSchedules|subscriptionPrices|appPricePoints.*POST",
}
EMAIL_TOOL = re.compile(r"(send_message|reply|forward)$")
WRITE = re.compile(r"\b(POST|PATCH|DELETE)\b")


def main():
    mode = sys.argv[1]
    event = json.load(sys.stdin)
    tool = event.get("tool_name", "")
    text = json.dumps(event.get("tool_input", {}))

    if mode == "pre":
        kinds = [k for k, pat in GUARDED.items() if re.search(pat, text, re.I)]
        if tool.startswith("mcp__") and EMAIL_TOOL.search(tool):
            kinds.append("email")
        missing = [k for k in kinds
                   if not os.path.exists(os.path.join(ROOT, "growth", "approvals", f"{k}.ok"))]
        if missing:
            print(f"Blocked by the growth guard: this looks like a {', '.join(missing)} action. "
                  f"It needs Josiah's OK on this exact change, recorded in "
                  f"growth/approvals/<kind>.ok, before it can run.", file=sys.stderr)
            sys.exit(2)
    elif mode == "post" and "appstoreconnect" in text and WRITE.search(text):
        stamp = datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z"
        lines = [l.strip() for l in text.replace("\\n", "\n").splitlines()
                 if WRITE.search(l) and ("/v1/" in l or "/v2/" in l)]
        with open(os.path.join(ROOT, "growth", "audit.log"), "a") as f:
            for l in lines[:20] or [text[:300]]:
                f.write(f"{stamp} [{tool}] {l[:300]}\n")


if __name__ == "__main__":
    main()
