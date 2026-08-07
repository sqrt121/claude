const page = await browser.getPage("PAGEID");
const out = await page.evaluate(async () => {
  const styleIds = new Set();
  function ser(n, depth) {
    const o = { id: n.id, name: n.name, type: n.type, x: Math.round(n.x), y: Math.round(n.y),
                w: Math.round(n.width), h: Math.round(n.height) };
    if (n.visible === false) { o.hidden = true; return o; }
    if (n.layoutMode && n.layoutMode !== "NONE") {
      o.layout = n.layoutMode; o.gap = n.itemSpacing;
      if (n.layoutWrap === "WRAP") { o.wrap = true; o.wrapGap = n.counterAxisSpacing; }
      o.pad = [n.paddingTop, n.paddingRight, n.paddingBottom, n.paddingLeft];
      if (n.primaryAxisAlignItems) o.mainAlign = n.primaryAxisAlignItems;
      if (n.counterAxisAlignItems) o.crossAlign = n.counterAxisAlignItems;
      if (n.itemReverseZIndex) o.revZ = true;
    }
    if (n.maxWidth) o.maxW = n.maxWidth;
    if (n.minWidth) o.minW = n.minWidth;
    if (n.layoutSizingHorizontal) o.sizeH = n.layoutSizingHorizontal;
    if (n.layoutSizingVertical) o.sizeV = n.layoutSizingVertical;
    if (typeof n.cornerRadius === "number" && n.cornerRadius) o.radius = n.cornerRadius;
    if (typeof n.opacity === "number" && n.opacity !== 1) o.opacity = Math.round(n.opacity * 100) / 100;
    try { if (n.effects && n.effects.length) o.fx = n.effects.map(e => ({ t: e.type, v: e.visible !== false, r: e.radius, off: e.offset, a: e.color && Math.round(e.color.a * 100) / 100 })); } catch (e) {}
    if (n.type === "TEXT") {
      o.fontSize = n.fontSize;
      o.lineHeight = n.lineHeight && n.lineHeight.unit !== "AUTO" ? (n.lineHeight.value + n.lineHeight.unit) : "auto";
      try { o.font = n.fontName.family + " " + n.fontName.style; } catch (e) {}
      try { if (n.letterSpacing && n.letterSpacing.value) o.tracking = n.letterSpacing.value + n.letterSpacing.unit; } catch (e) {}
      o.chars = n.characters.slice(0, 60);
      if (n.textStyleId && typeof n.textStyleId === "string") { o.textStyleId = n.textStyleId; styleIds.add(n.textStyleId); }
    }
    try {
      if (n.fills && n.fills.length) {
        o.fills = n.fills.filter(f => f.visible !== false).map(f => {
          const r = { t: f.type };
          if (f.type === "SOLID") { const c = f.color; r.rgb = [c.r, c.g, c.b].map(v => Math.round(v * 255)).join(","); }
          if (typeof f.opacity === "number" && f.opacity !== 1) r.a = Math.round(f.opacity * 100) / 100;
          return r;
        });
        if (!o.fills.length) delete o.fills;
      }
    } catch (e) {}
    if (n.fillStyleId && typeof n.fillStyleId === "string") { o.fillStyleId = n.fillStyleId; styleIds.add(n.fillStyleId); }
    try {
      const s = n.strokes && n.strokes[0];
      if (s && s.type === "SOLID" && s.visible !== false) {
        const c = s.color;
        o.stroke = [c.r, c.g, c.b].map(v => Math.round(v * 255)).join(",");
        if (typeof s.opacity === "number" && s.opacity !== 1) o.strokeA = Math.round(s.opacity * 100) / 100;
        if (typeof n.strokeWeight === "number") o.strokeW = n.strokeWeight;
        else o.strokeW = { t: n.strokeTopWeight, r: n.strokeRightWeight, b: n.strokeBottomWeight, l: n.strokeLeftWeight };
        if (n.strokeStyleId && typeof n.strokeStyleId === "string") { o.strokeStyleId = n.strokeStyleId; styleIds.add(n.strokeStyleId); }
      }
    } catch (e) {}
    if (n.type === "INSTANCE") {
      try { if (n.mainComponent) o.main = n.mainComponent.name; } catch (e) {}
      try { if (n.componentProperties) { const p = {}; for (const k in n.componentProperties) p[k.split("#")[0]] = n.componentProperties[k].value; o.props = p; } } catch (e) {}
    }
    if (depth > 0 && n.children) o.children = n.children.map(c => ser(c, depth - 1)).filter(Boolean);
    return o;
  }
  const frame = await figma.getNodeByIdAsync("NODEID");
  if (!frame) return { error: "not found: NODEID" };
  const tree = ser(frame, 16);
  const styles = {};
  for (const sid of styleIds) {
    try { const st = await figma.getStyleByIdAsync(sid); if (st) styles[sid] = st.name; } catch (e) {}
  }
  return { tree, styles };
});
console.log(JSON.stringify(out));
