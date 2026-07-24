import json, glob, os
base="/Users/vincentjeon/Desktop/code/3_personal/1_MacOptimizationTool"
langs=["ko","en","zh","ja"]
sw={"ko":"korean","en":"english","zh":"chinese","ja":"japanese"}
merged={l:{} for l in langs}
dupes=[]
files=sorted(glob.glob(base+"/.i18n_out/i18n_*.json"))
for f in files:
    d=json.load(open(f,encoding="utf-8"))
    for k,v in d.items():
        if k in merged["ko"]: dupes.append(k)
        for l in langs:
            merged[l][k]=v.get(l, v.get("en",k))
def esc(s): return s.replace("\\","\\\\").replace('"','\\"').replace("\n","\\n")
out=["// 자동 생성 파일 — 직접 수정하지 말 것. (scripts/gen_i18n.py 로 .i18n_out/*.json 병합 생성)",
     "enum GeneratedTranslations {",
     "    static let all: [AppLanguage: [String: String]] = ["]
for l in langs:
    out.append(f"        .{sw[l]}: [")
    for k in sorted(merged[l].keys()):
        out.append(f'            "{esc(k)}": "{esc(merged[l][k])}",')
    out.append("        ],")
out.append("    ]")
out.append("}")
open(base+"/Sources/GeneratedTranslations.swift","w",encoding="utf-8").write("\n".join(out)+"\n")
print("files:",len(files),"keys:",len(merged["ko"]),"dupes:",sorted(set(dupes)))
