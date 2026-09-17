#!/usr/bin/env python3
"""Build docs/ (GitHub Pages) from site/template.html: English at /, Traditional Chinese at /zh/."""
import os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tpl = open(os.path.join(ROOT, 'site/template.html'), encoding='utf-8').read()

HEAD = '''<!doctype html>
<html lang="{lang}">
<head>
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="description" content="{desc}">
<meta property="og:title" content="UTUVO Paw"><meta property="og:description" content="{desc}"><meta property="og:image" content="https://mickyyang-1407.github.io/utuvo-paw/assets/og.png"><meta name="twitter:card" content="summary_large_image">
<link rel="alternate" hreflang="en" href="https://mickyyang-1407.github.io/utuvo-paw/"><link rel="alternate" hreflang="zh-Hant" href="https://mickyyang-1407.github.io/utuvo-paw/zh/">
<link rel="icon" href="{base}assets/logo.webp">
'''

ZH = {
 # hero
 "The uninstaller with <em>paws</em>. Drop an app in. The cat finds every leftover. Then it throws things.": "有<em>貓掌</em>的解除安裝器。把 app 丟進來，貓幫你找出每一個殘留檔，然後把它們丟出去。",
 "Download": "下載", "GitHub": "GitHub", "Help": "求助",
 "Free. Open source. MIT licensed. No fish required.": "免費・開源・MIT 授權・不用付小魚乾",
 "Click an app · the cat does the rest": "點一個 app・剩下交給貓",
 "desk clear 🐾": "桌面清空 🐾",
 # drag drop boop
 "Drag. Drop. <span class=\"b\">Boop.</span>": "拖・放・<span class=\"b\">拍飛。</span>",
 "The most huggable uninstaller for macOS. Drag in any app and UTUVO Paw <strong>sniffs out every leftover file</strong> — caches, preferences, support folders. Then a <strong>real cat paw</strong> knocks them all off the desk. Because that's what cats do.":
 "macOS 上最想抱的解除安裝器。把任何 app 拖進來，UTUVO Paw 會<strong>嗅出每一個殘留檔</strong>——快取、偏好設定、支援資料夾。然後一隻<strong>真的貓掌</strong>把它們全部推下桌。因為貓就是這樣。",
 "Drop apps here": "把 app 丟到這裡",
 "Cliply — 7 things found": "Cliply — 找到 7 樣東西",
 "App Support": "App Support", "Login item": "登入項目", "Bop All 🐾": "全部拍飛 🐾",
 "bye bye": "掰掰",
 "1. Drop an app<small>The cat is napping. For now.</small>": "1. 丟一個 app 進來<small>貓還在睡。暫時。</small>",
 "2. Whiskers find everything<small>Nothing hides from a cat.</small>": "2. 鬍鬚找出所有東西<small>沒有東西躲得過貓。</small>",
 "3. Off the desk<small>Gone. Completely. Purr.</small>": "3. 推下桌<small>沒了。徹底。呼嚕。</small>",
 # ready aim boop
 "Ready. <span class=\"b\">Aim.</span> Boop.": "預備・<span class=\"b\">瞄準・</span>拍飛。",
 "The whiskers.": "鬍鬚。", "Sniff out every leftover an app drops on your Mac. Caches, preferences, support files — target locked.": "嗅出 app 留在 Mac 上的每一個殘留。快取、偏好設定、支援檔——目標鎖定。",
 "Toe beans.": "肉球。", "Soft on your Mac, firm on junk. Nothing you actually need gets bopped.": "對 Mac 溫柔，對垃圾狠。你真正需要的東西不會被拍。",
 "One bop.": "一拍。", "One click, one swipe. Or use Bop All to clear the whole desk, automatically.": "點一下、拍一下。或者按「全部拍飛」讓貓自己清桌。",
 "Built to pounce.": "天生會撲。", "Rebuilt with the fluidity, agility and smoothness of a cat landing on its feet. Every time.": "像貓落地一樣流暢、敏捷、穩。每一次。",
 "The tail.": "尾巴。", "Purely for style. Classic tabby, or pick one of the new coats to bop in style.": "純粹好看。經典虎斑，或換一件新毛色帥氣地拍。",
 "Fits your lap.": "剛好一個大腿。", "Manageable recoil, instant mouse aiming, and a purr when the job is done.": "後座力可控、滑鼠即時瞄準，做完還會呼嚕。",
 # nine lives
 "Nine lives of <span class=\"b\">love.</span>": "九條命的<span class=\"b\">愛。</span>",
 "Cats have been knocking things off desks since <strong>forever</strong>. We simply gave them a Mac.<br>Here is what the <strong>testing cats</strong> had to say.": "貓從<strong>有史以來</strong>就在把東西推下桌。我們只是給了牠們一台 Mac。<br>以下是<strong>測試貓</strong>的評語。",
 "\"Finally an uninstaller that respects the paw.\"": "「終於有一個尊重貓掌的解除安裝器。」",
 "\"I bopped 23 apps before breakfast. Then I had breakfast. Then I bopped two more.\"": "「早餐前拍飛了 23 個 app。然後吃早餐。然後再拍兩個。」",
 "\"Meow.\"": "「喵。」",
 "\"The whiskers found a plist my human didn't even know existed. Typical human.\"": "「鬍鬚找到一個我的人類根本不知道存在的 plist。人類就這樣。」",
 "\"Bop All is my favourite button. It is also my only button.\"": "「『全部拍飛』是我最愛的按鈕。也是我唯一的按鈕。」",
 "\"Always one of the first things I install on a new Mac. Right after sitting on the keyboard.\"": "「新 Mac 第一批裝的東西。就在坐上鍵盤之後。」",
 "\"Purrs when done. I purr when done. We are the same.\"": "「做完會呼嚕。我做完也呼嚕。我們是一樣的。」",
 "\"Soft on the Mac, firm on the junk. Same as my policy on the sofa.\"": "「對 Mac 溫柔、對垃圾狠。跟我對沙發的政策一樣。」",
 "\"10/10 would knock things off the desk again.\"": "「10/10，還會再把東西推下桌。」",
 "Mochi, 4": "麻糬・4 歲", "Tofu, 2": "豆腐・2 歲", "Butter, 11": "奶油・11 歲", "Pudding, 6": "布丁・6 歲", "Nori, 3": "海苔・3 歲",
 "Sesame, 8": "芝麻・8 歲", "Miso, 5": "味噌・5 歲", "Dumpling, 7": "水餃・7 歲", "Bean, 1": "豆豆・1 歲",
 # footer
 "© 2026 UTUVO · MIT License": "© 2026 UTUVO・MIT 授權", "Made with paws in Taipei": "台北・用貓掌做的", "No apps were harmed. Slightly bopped.": "沒有 app 受傷。只是被拍了一下。",
 "Playable demo: click an app to throw a shuriken at it": "可玩的示範：點一個 app，貓會丟手裡劍",
}
DESC = {'en': "UTUVO Paw — the free, open-source macOS uninstaller with paws. Drop an app in, the cat finds every leftover file and throws it in the Trash.",
        'zh': "UTUVO Paw——免費開源、有貓掌的 macOS 解除安裝器。把 app 丟進來，貓找出每一個殘留檔，然後丟進垃圾桶。"}

def build(lang):
    s = tpl
    base = '' if lang == 'en' else '../'
    if lang == 'zh':
        for en, zh in ZH.items():
            if en not in s: sys.exit(f'zh: string not found in template: {en[:60]}')
            s = s.replace(en, zh)
        s = s.replace('<html lang="en">', '<html lang="zh-Hant">')
        s = s.replace("'boop!','bop!','nyoom!','swish!'", "'拍！','啪！','咻！','喵？'")
        s = s.replace("n+' bopped'", "'拍飛 '+n+' 個'").replace('>0 bopped<', '>拍飛 0 個<')
        s = s.replace('--body:"Nunito","Helvetica Neue",Arial,sans-serif;', '--body:"Nunito","PingFang TC","Noto Sans TC","Helvetica Neue",Arial,sans-serif;')
        s = s.replace('.big{font-size:clamp(2.4rem,7vw,4.4rem);', '.big{font-family:var(--body);font-weight:800;font-size:clamp(2rem,6vw,3.6rem);')
        s = s.replace('<a href="./" data-lang="en">EN</a><a href="zh/" data-lang="zh">中文</a>', '<a href="../" data-lang="en">EN</a><a href="./" data-lang="zh" aria-current="page">中文</a>')
    else:
        s = s.replace('<a href="./" data-lang="en">EN</a>', '<a href="./" data-lang="en" aria-current="page">EN</a>')
    s = s.replace('src="assets/', f'src="{base}assets/').replace("'assets/", f"'{base}assets/")
    # remember the choice; on the English page, a Chinese browser with no choice goes to /zh/
    s = s.replace('</script>', '''
document.querySelectorAll('.lang a').forEach(function(a){a.addEventListener('click',function(){try{localStorage.setItem('paw-lang',a.dataset.lang)}catch(e){}})});
''' + ("try{if(!localStorage.getItem('paw-lang')&&/^zh/i.test(navigator.language)){location.replace('zh/')}}catch(e){}\n" if lang == 'en' else '') + '</script>', 1)
    head = HEAD.format(lang='en' if lang == 'en' else 'zh-Hant', desc=DESC[lang], base=base)
    i = s.index('</style>') + len('</style>')
    out = head + s[:i] + '\n</head>\n<body>\n' + s[i:].lstrip('\n') + '\n</body>\n</html>\n'
    path = os.path.join(ROOT, 'docs', 'index.html' if lang == 'en' else 'zh/index.html')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w', encoding='utf-8').write(out); print('wrote', os.path.relpath(path, ROOT), len(out))

build('en'); build('zh')
