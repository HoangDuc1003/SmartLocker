import re, sys, json, urllib.request, datetime
t = open(sys.argv[1], encoding="utf-8").read()
dois = re.findall(r"doi: ([^\s,]+?)\.?\s*$", t, re.M)
out = []
for d in dois:
    url = "https://api.crossref.org/works/" + d
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "doi-check/1.0"}), timeout=30)
        m = json.load(r)["message"]
        out.append({"doi": d, "status": 200, "title": (m.get("title") or [""])[0][:90], "year": (m.get("issued", {}).get("date-parts") or [[None]])[0][0],
                    "container": (m.get("container-title") or [""])[0][:60], "volume": m.get("volume"), "page": m.get("page")})
    except Exception as e:
        out.append({"doi": d, "status": str(e)})
for o in out: print(json.dumps(o, ensure_ascii=False))
json.dump({"checked_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "results": out}, open(sys.argv[2], "w"), indent=1)
