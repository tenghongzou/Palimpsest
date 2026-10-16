import json, sys
MARK_DEFS = '<linearGradient id="pg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1890FF"/><stop offset="1" stop-color="#0E7BE8"/></linearGradient>'
MARK_BODY = '''<rect width="1024" height="1024" rx="205" fill="url(#pg)"/>
<g transform="translate(256 272)">
<path fill="#5FAFF5" fill-rule="evenodd" d="M80 -80H392L512 40V118A180 180 0 0 1 332 298H216V480H80ZM216 36H304A72 72 0 0 1 304 180H216Z"/><path fill="#44A3F9" d="M392 -80V40H512Z"/>
<path fill="#F5F0E0" fill-rule="evenodd" d="M0 0H312L432 120V198A180 180 0 0 1 252 378H136V560H0ZM136 116H224A72 72 0 0 1 224 260H136Z"/><path fill="#DDD2B4" d="M312 0V120H432Z"/>
</g>'''

def horizontal(wm, color, cap_ratio=0.46, gap=0.30):
    s = 1024 * cap_ratio / wm['cap']
    xmin, ymin, xmax, ymax = wm['bounds']
    baseline = (1024 - 1024 * cap_ratio) / 2 + 1024 * cap_ratio
    x0 = 1024 + 1024 * gap
    w = x0 + (xmax - xmin) * s
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.0f} 1024">'
            f'<defs>{MARK_DEFS}</defs>{MARK_BODY}'
            f'<path fill="{color}" transform="translate({x0 - xmin * s:.2f} {baseline:.2f}) scale({s:.5f})" d="{wm["d"]}"/></svg>')

def stacked(wm, color, width_ratio=1.7, gap=0.22):
    xmin, ymin, xmax, ymax = wm['bounds']
    tw = 1024 * width_ratio
    s = tw / (xmax - xmin)
    W = tw
    mark_x = (W - 1024) / 2
    baseline = 1024 + 1024 * gap + wm['cap'] * s
    H = baseline + max(ymax, 0) * s
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H:.0f}">'
            f'<defs>{MARK_DEFS}</defs><g transform="translate({mark_x:.2f} 0)">{MARK_BODY}</g>'
            f'<path fill="{color}" transform="translate({-xmin * s:.2f} {baseline:.2f}) scale({s:.5f})" d="{wm["d"]}"/></svg>')

def wordmark(wm, color):
    xmin, ymin, xmax, ymax = wm['bounds']
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{xmin:.0f} {ymin:.0f} {xmax - xmin:.0f} {ymax - ymin:.0f}">'
            f'<path fill="{color}" d="{wm["d"]}"/></svg>')

if __name__ == '__main__':
    html = ['<html><body style="margin:0;font-family:sans-serif">']
    for n in ['baskerville', 'fraunces', 'cormorant']:
        wm = json.load(open(f'wm_{n}.json'))
        for bg, fg in [('#FFFFFF', '#1F2937'), ('#18181C', '#F5F0E0')]:
            open(f'h_{n}_{"light" if bg=="#FFFFFF" else "dark"}.svg', 'w').write(horizontal(wm, fg))
            html.append(f'<div style="background:{bg};padding:24px;display:flex;gap:40px;align-items:center">'
                        f'<span style="color:#888;width:110px">{n}</span>'
                        f'<img src="h_{n}_{"light" if bg=="#FFFFFF" else "dark"}.svg" style="height:56px">'
                        f'<img src="h_{n}_{"light" if bg=="#FFFFFF" else "dark"}.svg" style="height:28px"></div>')
    html.append('</body></html>')
    open('preview.html', 'w').write('\n'.join(html))
